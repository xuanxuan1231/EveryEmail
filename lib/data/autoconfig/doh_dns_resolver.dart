import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

/// 一条 SRV 记录（RFC 2782）。
class SrvRecord {
  const SrvRecord({
    required this.priority,
    required this.weight,
    required this.port,
    required this.target,
  });

  final int priority;
  final int weight;
  final int port;

  /// 目标主机名（已去除末尾的根点）。
  final String target;
}

/// 一条 MX 记录。
class MxRecord {
  const MxRecord({required this.preference, required this.exchange});

  final int preference;

  /// 邮件交换主机名（已去除末尾根点、转小写）。
  final String exchange;
}

/// 基于 DoH（DNS over HTTPS）的 DNS 解析器，多端点并发 fallback。
///
/// 为什么不用系统 DNS / basic_utils：enough_mail 的 DNS 走 basic_utils，端点硬编码到
/// dns.google / cloudflare，二者在中国大陆均不可达。这里并发查询「国内（阿里/腾讯）+
/// 国际（Google/Cloudflare）」四个 DoH 端点，取最先返回的有效结果——大陆走国内、海外
/// 走国际，无需地理判断。所有端点统一用 `application/dns-json`（GET `?name=&type=`）。
class DohDnsResolver {
  DohDnsResolver({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 5),
                responseType: ResponseType.json,
                headers: const {'Accept': 'application/dns-json'},
              ),
            );

  final Dio _dio;

  /// DoH 端点（并发查询、取最快有效）。顺序仅为可读性，不影响并发。
  static const List<String> endpoints = [
    'https://dns.alidns.com/resolve', // 阿里 AliDNS (223.5.5.5)
    'https://doh.pub/dns-query', // 腾讯 DNSPod (119.29.29.29)
    'https://dns.google/resolve', // Google
    'https://cloudflare-dns.com/dns-query', // Cloudflare
  ];

  static const int _typeMx = 15;
  static const int _typeSrv = 33;
  static const int _typeCname = 5;

  /// 查询 SRV 记录（如 `_imaps._tcp.example.com`）。无结果返回空列表。
  Future<List<SrvRecord>> lookupSrv(String name) async {
    final answers = await _resolve(name, _typeSrv);
    return answers
        .map(parseSrvData)
        .whereType<SrvRecord>()
        .toList(growable: false);
  }

  /// 查询 MX 记录。无结果返回空列表。
  Future<List<MxRecord>> lookupMx(String domain) async {
    final answers = await _resolve(domain, _typeMx);
    return answers
        .map(parseMxData)
        .whereType<MxRecord>()
        .toList(growable: false);
  }

  /// 查询 CNAME 记录，返回目标主机名（去尾点、转小写）。无结果返回空列表。
  Future<List<String>> lookupCname(String name) async {
    final answers = await _resolve(name, _typeCname);
    return answers.map(normalizeHost).toList(growable: false);
  }

  /// 向所有端点并发查询，返回**最先成功且非空**的 Answer 的 data 字段列表；
  /// 全部失败/为空则返回空列表。
  ///
  /// 注意不能用 [Future.any]——它取首个「完成」而非首个「成功」，失败会提前胜出。
  Future<List<String>> _resolve(String name, int type) {
    final completer = Completer<List<String>>();
    var pending = endpoints.length;
    for (final endpoint in endpoints) {
      _queryEndpoint(endpoint, name, type).then((data) {
        if (data != null && data.isNotEmpty && !completer.isCompleted) {
          completer.complete(data);
        }
      }).whenComplete(() {
        pending--;
        if (pending == 0 && !completer.isCompleted) {
          completer.complete(const []);
        }
      });
    }
    return completer.future;
  }

  /// 查询单个端点；失败/超时/无匹配 Answer 返回 `null`（吞掉异常，不影响其他端点）。
  Future<List<String>?> _queryEndpoint(
    String endpoint,
    String name,
    int type,
  ) async {
    try {
      final response = await _dio.get<dynamic>(
        endpoint,
        queryParameters: {'name': name, 'type': type.toString()},
      );
      final body = response.data;
      final json = body is String
          ? jsonDecode(body) as Map<String, dynamic>
          : body as Map<String, dynamic>;
      final answer = json['Answer'];
      if (answer is! List) return null;
      final data = <String>[];
      for (final entry in answer) {
        // 只取请求类型的记录（过滤 CNAME 等串联结果）。
        if (entry is Map && entry['type'] == type) {
          final d = entry['data'];
          if (d is String && d.isNotEmpty) data.add(d);
        }
      }
      return data.isEmpty ? null : data;
    } catch (_) {
      return null; // 单端点失败被吞，交由其他端点
    }
  }

  /// 解析 SRV 的 data 字段：`"priority weight port target"`。
  /// `target == "."` 表示服务显式不可用，返回 `null`。
  static SrvRecord? parseSrvData(String data) {
    final parts = data.trim().split(RegExp(r'\s+'));
    if (parts.length < 4) return null;
    final priority = int.tryParse(parts[0]);
    final weight = int.tryParse(parts[1]);
    final port = int.tryParse(parts[2]);
    var target = parts[3];
    if (priority == null || weight == null || port == null) return null;
    if (target == '.' || target.isEmpty) return null;
    if (target.endsWith('.')) {
      target = target.substring(0, target.length - 1);
    }
    return SrvRecord(
      priority: priority,
      weight: weight,
      port: port,
      target: target,
    );
  }

  /// 解析 MX 的 data 字段：`"preference exchange"`。
  static MxRecord? parseMxData(String data) {
    final parts = data.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return null;
    final preference = int.tryParse(parts[0]);
    var exchange = parts[1];
    if (preference == null || exchange.isEmpty || exchange == '.') return null;
    if (exchange.endsWith('.')) {
      exchange = exchange.substring(0, exchange.length - 1);
    }
    return MxRecord(preference: preference, exchange: exchange.toLowerCase());
  }

  /// 归一化主机名：去末尾根点 + 转小写。
  static String normalizeHost(String host) {
    var h = host.trim().toLowerCase();
    if (h.endsWith('.')) h = h.substring(0, h.length - 1);
    return h;
  }
}
