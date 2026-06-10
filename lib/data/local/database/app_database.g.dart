// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AccountsTable extends Accounts with TableInfo<$AccountsTable, Account> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AccountType, int> accountType =
      GeneratedColumn<int>(
        'account_type',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<AccountType>($AccountsTable.$converteraccountType);
  @override
  late final GeneratedColumnWithTypeConverter<AuthType, int> authType =
      GeneratedColumn<int>(
        'auth_type',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<AuthType>($AccountsTable.$converterauthType);
  static const VerificationMeta _secretRefMeta = const VerificationMeta(
    'secretRef',
  );
  @override
  late final GeneratedColumn<String> secretRef = GeneratedColumn<String>(
    'secret_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imapHostMeta = const VerificationMeta(
    'imapHost',
  );
  @override
  late final GeneratedColumn<String> imapHost = GeneratedColumn<String>(
    'imap_host',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imapPortMeta = const VerificationMeta(
    'imapPort',
  );
  @override
  late final GeneratedColumn<int> imapPort = GeneratedColumn<int>(
    'imap_port',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SocketType?, int> imapSocketType =
      GeneratedColumn<int>(
        'imap_socket_type',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<SocketType?>($AccountsTable.$converterimapSocketTypen);
  static const VerificationMeta _smtpHostMeta = const VerificationMeta(
    'smtpHost',
  );
  @override
  late final GeneratedColumn<String> smtpHost = GeneratedColumn<String>(
    'smtp_host',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _smtpPortMeta = const VerificationMeta(
    'smtpPort',
  );
  @override
  late final GeneratedColumn<int> smtpPort = GeneratedColumn<int>(
    'smtp_port',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SocketType?, int> smtpSocketType =
      GeneratedColumn<int>(
        'smtp_socket_type',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<SocketType?>($AccountsTable.$convertersmtpSocketTypen);
  static const VerificationMeta _loginNameMeta = const VerificationMeta(
    'loginName',
  );
  @override
  late final GeneratedColumn<String> loginName = GeneratedColumn<String>(
    'login_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    email,
    displayName,
    accountType,
    authType,
    secretRef,
    imapHost,
    imapPort,
    imapSocketType,
    smtpHost,
    smtpPort,
    smtpSocketType,
    loginName,
    colorValue,
    sortIndex,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Account> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('secret_ref')) {
      context.handle(
        _secretRefMeta,
        secretRef.isAcceptableOrUnknown(data['secret_ref']!, _secretRefMeta),
      );
    }
    if (data.containsKey('imap_host')) {
      context.handle(
        _imapHostMeta,
        imapHost.isAcceptableOrUnknown(data['imap_host']!, _imapHostMeta),
      );
    }
    if (data.containsKey('imap_port')) {
      context.handle(
        _imapPortMeta,
        imapPort.isAcceptableOrUnknown(data['imap_port']!, _imapPortMeta),
      );
    }
    if (data.containsKey('smtp_host')) {
      context.handle(
        _smtpHostMeta,
        smtpHost.isAcceptableOrUnknown(data['smtp_host']!, _smtpHostMeta),
      );
    }
    if (data.containsKey('smtp_port')) {
      context.handle(
        _smtpPortMeta,
        smtpPort.isAcceptableOrUnknown(data['smtp_port']!, _smtpPortMeta),
      );
    }
    if (data.containsKey('login_name')) {
      context.handle(
        _loginNameMeta,
        loginName.isAcceptableOrUnknown(data['login_name']!, _loginNameMeta),
      );
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Account map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Account(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      accountType: $AccountsTable.$converteraccountType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}account_type'],
        )!,
      ),
      authType: $AccountsTable.$converterauthType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}auth_type'],
        )!,
      ),
      secretRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}secret_ref'],
      ),
      imapHost: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}imap_host'],
      ),
      imapPort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}imap_port'],
      ),
      imapSocketType: $AccountsTable.$converterimapSocketTypen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}imap_socket_type'],
        ),
      ),
      smtpHost: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}smtp_host'],
      ),
      smtpPort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}smtp_port'],
      ),
      smtpSocketType: $AccountsTable.$convertersmtpSocketTypen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}smtp_socket_type'],
        ),
      ),
      loginName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}login_name'],
      ),
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      ),
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AccountType, int, int> $converteraccountType =
      const EnumIndexConverter<AccountType>(AccountType.values);
  static JsonTypeConverter2<AuthType, int, int> $converterauthType =
      const EnumIndexConverter<AuthType>(AuthType.values);
  static JsonTypeConverter2<SocketType, int, int> $converterimapSocketType =
      const EnumIndexConverter<SocketType>(SocketType.values);
  static JsonTypeConverter2<SocketType?, int?, int?> $converterimapSocketTypen =
      JsonTypeConverter2.asNullable($converterimapSocketType);
  static JsonTypeConverter2<SocketType, int, int> $convertersmtpSocketType =
      const EnumIndexConverter<SocketType>(SocketType.values);
  static JsonTypeConverter2<SocketType?, int?, int?> $convertersmtpSocketTypen =
      JsonTypeConverter2.asNullable($convertersmtpSocketType);
}

class Account extends DataClass implements Insertable<Account> {
  /// 内部稳定主键（UUID 字符串）。
  final String id;
  final String email;
  final String displayName;

  /// 账户类型（gmailOAuth / microsoftGraph / genericImap）。
  final AccountType accountType;

  /// 认证方式（oauth / password）。
  final AuthType authType;

  /// 安全存储中密钥条目的键名（refresh token 或密码）。
  final String? secretRef;
  final String? imapHost;
  final int? imapPort;
  final SocketType? imapSocketType;
  final String? smtpHost;
  final int? smtpPort;
  final SocketType? smtpSocketType;

  /// IMAP/SMTP 登录用户名（通常即 email，但允许不同）。
  final String? loginName;

  /// 账户配色种子（用于多账户区分），存 ARGB。
  final int? colorValue;

  /// 排序序号（多账户列表）。
  final int sortIndex;
  final DateTime createdAt;
  const Account({
    required this.id,
    required this.email,
    required this.displayName,
    required this.accountType,
    required this.authType,
    this.secretRef,
    this.imapHost,
    this.imapPort,
    this.imapSocketType,
    this.smtpHost,
    this.smtpPort,
    this.smtpSocketType,
    this.loginName,
    this.colorValue,
    required this.sortIndex,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['email'] = Variable<String>(email);
    map['display_name'] = Variable<String>(displayName);
    {
      map['account_type'] = Variable<int>(
        $AccountsTable.$converteraccountType.toSql(accountType),
      );
    }
    {
      map['auth_type'] = Variable<int>(
        $AccountsTable.$converterauthType.toSql(authType),
      );
    }
    if (!nullToAbsent || secretRef != null) {
      map['secret_ref'] = Variable<String>(secretRef);
    }
    if (!nullToAbsent || imapHost != null) {
      map['imap_host'] = Variable<String>(imapHost);
    }
    if (!nullToAbsent || imapPort != null) {
      map['imap_port'] = Variable<int>(imapPort);
    }
    if (!nullToAbsent || imapSocketType != null) {
      map['imap_socket_type'] = Variable<int>(
        $AccountsTable.$converterimapSocketTypen.toSql(imapSocketType),
      );
    }
    if (!nullToAbsent || smtpHost != null) {
      map['smtp_host'] = Variable<String>(smtpHost);
    }
    if (!nullToAbsent || smtpPort != null) {
      map['smtp_port'] = Variable<int>(smtpPort);
    }
    if (!nullToAbsent || smtpSocketType != null) {
      map['smtp_socket_type'] = Variable<int>(
        $AccountsTable.$convertersmtpSocketTypen.toSql(smtpSocketType),
      );
    }
    if (!nullToAbsent || loginName != null) {
      map['login_name'] = Variable<String>(loginName);
    }
    if (!nullToAbsent || colorValue != null) {
      map['color_value'] = Variable<int>(colorValue);
    }
    map['sort_index'] = Variable<int>(sortIndex);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      email: Value(email),
      displayName: Value(displayName),
      accountType: Value(accountType),
      authType: Value(authType),
      secretRef: secretRef == null && nullToAbsent
          ? const Value.absent()
          : Value(secretRef),
      imapHost: imapHost == null && nullToAbsent
          ? const Value.absent()
          : Value(imapHost),
      imapPort: imapPort == null && nullToAbsent
          ? const Value.absent()
          : Value(imapPort),
      imapSocketType: imapSocketType == null && nullToAbsent
          ? const Value.absent()
          : Value(imapSocketType),
      smtpHost: smtpHost == null && nullToAbsent
          ? const Value.absent()
          : Value(smtpHost),
      smtpPort: smtpPort == null && nullToAbsent
          ? const Value.absent()
          : Value(smtpPort),
      smtpSocketType: smtpSocketType == null && nullToAbsent
          ? const Value.absent()
          : Value(smtpSocketType),
      loginName: loginName == null && nullToAbsent
          ? const Value.absent()
          : Value(loginName),
      colorValue: colorValue == null && nullToAbsent
          ? const Value.absent()
          : Value(colorValue),
      sortIndex: Value(sortIndex),
      createdAt: Value(createdAt),
    );
  }

  factory Account.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Account(
      id: serializer.fromJson<String>(json['id']),
      email: serializer.fromJson<String>(json['email']),
      displayName: serializer.fromJson<String>(json['displayName']),
      accountType: $AccountsTable.$converteraccountType.fromJson(
        serializer.fromJson<int>(json['accountType']),
      ),
      authType: $AccountsTable.$converterauthType.fromJson(
        serializer.fromJson<int>(json['authType']),
      ),
      secretRef: serializer.fromJson<String?>(json['secretRef']),
      imapHost: serializer.fromJson<String?>(json['imapHost']),
      imapPort: serializer.fromJson<int?>(json['imapPort']),
      imapSocketType: $AccountsTable.$converterimapSocketTypen.fromJson(
        serializer.fromJson<int?>(json['imapSocketType']),
      ),
      smtpHost: serializer.fromJson<String?>(json['smtpHost']),
      smtpPort: serializer.fromJson<int?>(json['smtpPort']),
      smtpSocketType: $AccountsTable.$convertersmtpSocketTypen.fromJson(
        serializer.fromJson<int?>(json['smtpSocketType']),
      ),
      loginName: serializer.fromJson<String?>(json['loginName']),
      colorValue: serializer.fromJson<int?>(json['colorValue']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'email': serializer.toJson<String>(email),
      'displayName': serializer.toJson<String>(displayName),
      'accountType': serializer.toJson<int>(
        $AccountsTable.$converteraccountType.toJson(accountType),
      ),
      'authType': serializer.toJson<int>(
        $AccountsTable.$converterauthType.toJson(authType),
      ),
      'secretRef': serializer.toJson<String?>(secretRef),
      'imapHost': serializer.toJson<String?>(imapHost),
      'imapPort': serializer.toJson<int?>(imapPort),
      'imapSocketType': serializer.toJson<int?>(
        $AccountsTable.$converterimapSocketTypen.toJson(imapSocketType),
      ),
      'smtpHost': serializer.toJson<String?>(smtpHost),
      'smtpPort': serializer.toJson<int?>(smtpPort),
      'smtpSocketType': serializer.toJson<int?>(
        $AccountsTable.$convertersmtpSocketTypen.toJson(smtpSocketType),
      ),
      'loginName': serializer.toJson<String?>(loginName),
      'colorValue': serializer.toJson<int?>(colorValue),
      'sortIndex': serializer.toJson<int>(sortIndex),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Account copyWith({
    String? id,
    String? email,
    String? displayName,
    AccountType? accountType,
    AuthType? authType,
    Value<String?> secretRef = const Value.absent(),
    Value<String?> imapHost = const Value.absent(),
    Value<int?> imapPort = const Value.absent(),
    Value<SocketType?> imapSocketType = const Value.absent(),
    Value<String?> smtpHost = const Value.absent(),
    Value<int?> smtpPort = const Value.absent(),
    Value<SocketType?> smtpSocketType = const Value.absent(),
    Value<String?> loginName = const Value.absent(),
    Value<int?> colorValue = const Value.absent(),
    int? sortIndex,
    DateTime? createdAt,
  }) => Account(
    id: id ?? this.id,
    email: email ?? this.email,
    displayName: displayName ?? this.displayName,
    accountType: accountType ?? this.accountType,
    authType: authType ?? this.authType,
    secretRef: secretRef.present ? secretRef.value : this.secretRef,
    imapHost: imapHost.present ? imapHost.value : this.imapHost,
    imapPort: imapPort.present ? imapPort.value : this.imapPort,
    imapSocketType: imapSocketType.present
        ? imapSocketType.value
        : this.imapSocketType,
    smtpHost: smtpHost.present ? smtpHost.value : this.smtpHost,
    smtpPort: smtpPort.present ? smtpPort.value : this.smtpPort,
    smtpSocketType: smtpSocketType.present
        ? smtpSocketType.value
        : this.smtpSocketType,
    loginName: loginName.present ? loginName.value : this.loginName,
    colorValue: colorValue.present ? colorValue.value : this.colorValue,
    sortIndex: sortIndex ?? this.sortIndex,
    createdAt: createdAt ?? this.createdAt,
  );
  Account copyWithCompanion(AccountsCompanion data) {
    return Account(
      id: data.id.present ? data.id.value : this.id,
      email: data.email.present ? data.email.value : this.email,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      accountType: data.accountType.present
          ? data.accountType.value
          : this.accountType,
      authType: data.authType.present ? data.authType.value : this.authType,
      secretRef: data.secretRef.present ? data.secretRef.value : this.secretRef,
      imapHost: data.imapHost.present ? data.imapHost.value : this.imapHost,
      imapPort: data.imapPort.present ? data.imapPort.value : this.imapPort,
      imapSocketType: data.imapSocketType.present
          ? data.imapSocketType.value
          : this.imapSocketType,
      smtpHost: data.smtpHost.present ? data.smtpHost.value : this.smtpHost,
      smtpPort: data.smtpPort.present ? data.smtpPort.value : this.smtpPort,
      smtpSocketType: data.smtpSocketType.present
          ? data.smtpSocketType.value
          : this.smtpSocketType,
      loginName: data.loginName.present ? data.loginName.value : this.loginName,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Account(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('displayName: $displayName, ')
          ..write('accountType: $accountType, ')
          ..write('authType: $authType, ')
          ..write('secretRef: $secretRef, ')
          ..write('imapHost: $imapHost, ')
          ..write('imapPort: $imapPort, ')
          ..write('imapSocketType: $imapSocketType, ')
          ..write('smtpHost: $smtpHost, ')
          ..write('smtpPort: $smtpPort, ')
          ..write('smtpSocketType: $smtpSocketType, ')
          ..write('loginName: $loginName, ')
          ..write('colorValue: $colorValue, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    email,
    displayName,
    accountType,
    authType,
    secretRef,
    imapHost,
    imapPort,
    imapSocketType,
    smtpHost,
    smtpPort,
    smtpSocketType,
    loginName,
    colorValue,
    sortIndex,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          other.id == this.id &&
          other.email == this.email &&
          other.displayName == this.displayName &&
          other.accountType == this.accountType &&
          other.authType == this.authType &&
          other.secretRef == this.secretRef &&
          other.imapHost == this.imapHost &&
          other.imapPort == this.imapPort &&
          other.imapSocketType == this.imapSocketType &&
          other.smtpHost == this.smtpHost &&
          other.smtpPort == this.smtpPort &&
          other.smtpSocketType == this.smtpSocketType &&
          other.loginName == this.loginName &&
          other.colorValue == this.colorValue &&
          other.sortIndex == this.sortIndex &&
          other.createdAt == this.createdAt);
}

class AccountsCompanion extends UpdateCompanion<Account> {
  final Value<String> id;
  final Value<String> email;
  final Value<String> displayName;
  final Value<AccountType> accountType;
  final Value<AuthType> authType;
  final Value<String?> secretRef;
  final Value<String?> imapHost;
  final Value<int?> imapPort;
  final Value<SocketType?> imapSocketType;
  final Value<String?> smtpHost;
  final Value<int?> smtpPort;
  final Value<SocketType?> smtpSocketType;
  final Value<String?> loginName;
  final Value<int?> colorValue;
  final Value<int> sortIndex;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.email = const Value.absent(),
    this.displayName = const Value.absent(),
    this.accountType = const Value.absent(),
    this.authType = const Value.absent(),
    this.secretRef = const Value.absent(),
    this.imapHost = const Value.absent(),
    this.imapPort = const Value.absent(),
    this.imapSocketType = const Value.absent(),
    this.smtpHost = const Value.absent(),
    this.smtpPort = const Value.absent(),
    this.smtpSocketType = const Value.absent(),
    this.loginName = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountsCompanion.insert({
    required String id,
    required String email,
    required String displayName,
    required AccountType accountType,
    required AuthType authType,
    this.secretRef = const Value.absent(),
    this.imapHost = const Value.absent(),
    this.imapPort = const Value.absent(),
    this.imapSocketType = const Value.absent(),
    this.smtpHost = const Value.absent(),
    this.smtpPort = const Value.absent(),
    this.smtpSocketType = const Value.absent(),
    this.loginName = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       email = Value(email),
       displayName = Value(displayName),
       accountType = Value(accountType),
       authType = Value(authType);
  static Insertable<Account> custom({
    Expression<String>? id,
    Expression<String>? email,
    Expression<String>? displayName,
    Expression<int>? accountType,
    Expression<int>? authType,
    Expression<String>? secretRef,
    Expression<String>? imapHost,
    Expression<int>? imapPort,
    Expression<int>? imapSocketType,
    Expression<String>? smtpHost,
    Expression<int>? smtpPort,
    Expression<int>? smtpSocketType,
    Expression<String>? loginName,
    Expression<int>? colorValue,
    Expression<int>? sortIndex,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (email != null) 'email': email,
      if (displayName != null) 'display_name': displayName,
      if (accountType != null) 'account_type': accountType,
      if (authType != null) 'auth_type': authType,
      if (secretRef != null) 'secret_ref': secretRef,
      if (imapHost != null) 'imap_host': imapHost,
      if (imapPort != null) 'imap_port': imapPort,
      if (imapSocketType != null) 'imap_socket_type': imapSocketType,
      if (smtpHost != null) 'smtp_host': smtpHost,
      if (smtpPort != null) 'smtp_port': smtpPort,
      if (smtpSocketType != null) 'smtp_socket_type': smtpSocketType,
      if (loginName != null) 'login_name': loginName,
      if (colorValue != null) 'color_value': colorValue,
      if (sortIndex != null) 'sort_index': sortIndex,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountsCompanion copyWith({
    Value<String>? id,
    Value<String>? email,
    Value<String>? displayName,
    Value<AccountType>? accountType,
    Value<AuthType>? authType,
    Value<String?>? secretRef,
    Value<String?>? imapHost,
    Value<int?>? imapPort,
    Value<SocketType?>? imapSocketType,
    Value<String?>? smtpHost,
    Value<int?>? smtpPort,
    Value<SocketType?>? smtpSocketType,
    Value<String?>? loginName,
    Value<int?>? colorValue,
    Value<int>? sortIndex,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return AccountsCompanion(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      accountType: accountType ?? this.accountType,
      authType: authType ?? this.authType,
      secretRef: secretRef ?? this.secretRef,
      imapHost: imapHost ?? this.imapHost,
      imapPort: imapPort ?? this.imapPort,
      imapSocketType: imapSocketType ?? this.imapSocketType,
      smtpHost: smtpHost ?? this.smtpHost,
      smtpPort: smtpPort ?? this.smtpPort,
      smtpSocketType: smtpSocketType ?? this.smtpSocketType,
      loginName: loginName ?? this.loginName,
      colorValue: colorValue ?? this.colorValue,
      sortIndex: sortIndex ?? this.sortIndex,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (accountType.present) {
      map['account_type'] = Variable<int>(
        $AccountsTable.$converteraccountType.toSql(accountType.value),
      );
    }
    if (authType.present) {
      map['auth_type'] = Variable<int>(
        $AccountsTable.$converterauthType.toSql(authType.value),
      );
    }
    if (secretRef.present) {
      map['secret_ref'] = Variable<String>(secretRef.value);
    }
    if (imapHost.present) {
      map['imap_host'] = Variable<String>(imapHost.value);
    }
    if (imapPort.present) {
      map['imap_port'] = Variable<int>(imapPort.value);
    }
    if (imapSocketType.present) {
      map['imap_socket_type'] = Variable<int>(
        $AccountsTable.$converterimapSocketTypen.toSql(imapSocketType.value),
      );
    }
    if (smtpHost.present) {
      map['smtp_host'] = Variable<String>(smtpHost.value);
    }
    if (smtpPort.present) {
      map['smtp_port'] = Variable<int>(smtpPort.value);
    }
    if (smtpSocketType.present) {
      map['smtp_socket_type'] = Variable<int>(
        $AccountsTable.$convertersmtpSocketTypen.toSql(smtpSocketType.value),
      );
    }
    if (loginName.present) {
      map['login_name'] = Variable<String>(loginName.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('displayName: $displayName, ')
          ..write('accountType: $accountType, ')
          ..write('authType: $authType, ')
          ..write('secretRef: $secretRef, ')
          ..write('imapHost: $imapHost, ')
          ..write('imapPort: $imapPort, ')
          ..write('imapSocketType: $imapSocketType, ')
          ..write('smtpHost: $smtpHost, ')
          ..write('smtpPort: $smtpPort, ')
          ..write('smtpSocketType: $smtpSocketType, ')
          ..write('loginName: $loginName, ')
          ..write('colorValue: $colorValue, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FoldersTable extends Folders with TableInfo<$FoldersTable, Folder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
    'remote_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<FolderType, int> folderType =
      GeneratedColumn<int>(
        'folder_type',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<FolderType>($FoldersTable.$converterfolderType);
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unreadCountMeta = const VerificationMeta(
    'unreadCount',
  );
  @override
  late final GeneratedColumn<int> unreadCount = GeneratedColumn<int>(
    'unread_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalCountMeta = const VerificationMeta(
    'totalCount',
  );
  @override
  late final GeneratedColumn<int> totalCount = GeneratedColumn<int>(
    'total_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isSubscribedMeta = const VerificationMeta(
    'isSubscribed',
  );
  @override
  late final GeneratedColumn<bool> isSubscribed = GeneratedColumn<bool>(
    'is_subscribed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_subscribed" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _visibleMeta = const VerificationMeta(
    'visible',
  );
  @override
  late final GeneratedColumn<bool> visible = GeneratedColumn<bool>(
    'visible',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("visible" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _syncEnabledMeta = const VerificationMeta(
    'syncEnabled',
  );
  @override
  late final GeneratedColumn<bool> syncEnabled = GeneratedColumn<bool>(
    'sync_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sync_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _notificationsEnabledMeta =
      const VerificationMeta('notificationsEnabled');
  @override
  late final GeneratedColumn<bool> notificationsEnabled = GeneratedColumn<bool>(
    'notifications_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("notifications_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _unifiedMeta = const VerificationMeta(
    'unified',
  );
  @override
  late final GeneratedColumn<bool> unified = GeneratedColumn<bool>(
    'unified',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("unified" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    remoteId,
    displayName,
    folderType,
    parentId,
    unreadCount,
    totalCount,
    isSubscribed,
    visible,
    syncEnabled,
    notificationsEnabled,
    unified,
    sortIndex,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<Folder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('unread_count')) {
      context.handle(
        _unreadCountMeta,
        unreadCount.isAcceptableOrUnknown(
          data['unread_count']!,
          _unreadCountMeta,
        ),
      );
    }
    if (data.containsKey('total_count')) {
      context.handle(
        _totalCountMeta,
        totalCount.isAcceptableOrUnknown(data['total_count']!, _totalCountMeta),
      );
    }
    if (data.containsKey('is_subscribed')) {
      context.handle(
        _isSubscribedMeta,
        isSubscribed.isAcceptableOrUnknown(
          data['is_subscribed']!,
          _isSubscribedMeta,
        ),
      );
    }
    if (data.containsKey('visible')) {
      context.handle(
        _visibleMeta,
        visible.isAcceptableOrUnknown(data['visible']!, _visibleMeta),
      );
    }
    if (data.containsKey('sync_enabled')) {
      context.handle(
        _syncEnabledMeta,
        syncEnabled.isAcceptableOrUnknown(
          data['sync_enabled']!,
          _syncEnabledMeta,
        ),
      );
    }
    if (data.containsKey('notifications_enabled')) {
      context.handle(
        _notificationsEnabledMeta,
        notificationsEnabled.isAcceptableOrUnknown(
          data['notifications_enabled']!,
          _notificationsEnabledMeta,
        ),
      );
    }
    if (data.containsKey('unified')) {
      context.handle(
        _unifiedMeta,
        unified.isAcceptableOrUnknown(data['unified']!, _unifiedMeta),
      );
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Folder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Folder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      folderType: $FoldersTable.$converterfolderType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}folder_type'],
        )!,
      ),
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      unreadCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unread_count'],
      )!,
      totalCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_count'],
      )!,
      isSubscribed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_subscribed'],
      )!,
      visible: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}visible'],
      )!,
      syncEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sync_enabled'],
      )!,
      notificationsEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notifications_enabled'],
      )!,
      unified: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}unified'],
      )!,
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      )!,
    );
  }

  @override
  $FoldersTable createAlias(String alias) {
    return $FoldersTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<FolderType, int, int> $converterfolderType =
      const EnumIndexConverter<FolderType>(FolderType.values);
}

class Folder extends DataClass implements Insertable<Folder> {
  /// 内部稳定主键（UUID）。
  final String id;
  final String accountId;

  /// 后端原生标识：IMAP 为文件夹路径（如 "INBOX/Work"），Graph 为 folderId。
  final String remoteId;
  final String displayName;

  /// 语义角色（inbox/sent/...）。
  final FolderType folderType;

  /// 父文件夹（层级展示），顶层为空。
  final String? parentId;
  final int unreadCount;
  final int totalCount;

  /// 是否可被 IDLE/同步监听（如 INBOX）。
  final bool isSubscribed;

  /// 是否在抽屉的文件夹列表中显示（用户级偏好，不影响同步本身）。
  final bool visible;

  /// 是否同步此文件夹的邮件（与账户级同步范围共同决定，二者皆真才同步）。
  final bool syncEnabled;

  /// 此文件夹收到新邮件时是否通知。
  final bool notificationsEnabled;

  /// 是否纳入统一账户的聚合视图（统一收件箱/已发送/草稿）。
  final bool unified;
  final int sortIndex;
  const Folder({
    required this.id,
    required this.accountId,
    required this.remoteId,
    required this.displayName,
    required this.folderType,
    this.parentId,
    required this.unreadCount,
    required this.totalCount,
    required this.isSubscribed,
    required this.visible,
    required this.syncEnabled,
    required this.notificationsEnabled,
    required this.unified,
    required this.sortIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    map['remote_id'] = Variable<String>(remoteId);
    map['display_name'] = Variable<String>(displayName);
    {
      map['folder_type'] = Variable<int>(
        $FoldersTable.$converterfolderType.toSql(folderType),
      );
    }
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['unread_count'] = Variable<int>(unreadCount);
    map['total_count'] = Variable<int>(totalCount);
    map['is_subscribed'] = Variable<bool>(isSubscribed);
    map['visible'] = Variable<bool>(visible);
    map['sync_enabled'] = Variable<bool>(syncEnabled);
    map['notifications_enabled'] = Variable<bool>(notificationsEnabled);
    map['unified'] = Variable<bool>(unified);
    map['sort_index'] = Variable<int>(sortIndex);
    return map;
  }

  FoldersCompanion toCompanion(bool nullToAbsent) {
    return FoldersCompanion(
      id: Value(id),
      accountId: Value(accountId),
      remoteId: Value(remoteId),
      displayName: Value(displayName),
      folderType: Value(folderType),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      unreadCount: Value(unreadCount),
      totalCount: Value(totalCount),
      isSubscribed: Value(isSubscribed),
      visible: Value(visible),
      syncEnabled: Value(syncEnabled),
      notificationsEnabled: Value(notificationsEnabled),
      unified: Value(unified),
      sortIndex: Value(sortIndex),
    );
  }

  factory Folder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Folder(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      remoteId: serializer.fromJson<String>(json['remoteId']),
      displayName: serializer.fromJson<String>(json['displayName']),
      folderType: $FoldersTable.$converterfolderType.fromJson(
        serializer.fromJson<int>(json['folderType']),
      ),
      parentId: serializer.fromJson<String?>(json['parentId']),
      unreadCount: serializer.fromJson<int>(json['unreadCount']),
      totalCount: serializer.fromJson<int>(json['totalCount']),
      isSubscribed: serializer.fromJson<bool>(json['isSubscribed']),
      visible: serializer.fromJson<bool>(json['visible']),
      syncEnabled: serializer.fromJson<bool>(json['syncEnabled']),
      notificationsEnabled: serializer.fromJson<bool>(
        json['notificationsEnabled'],
      ),
      unified: serializer.fromJson<bool>(json['unified']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'remoteId': serializer.toJson<String>(remoteId),
      'displayName': serializer.toJson<String>(displayName),
      'folderType': serializer.toJson<int>(
        $FoldersTable.$converterfolderType.toJson(folderType),
      ),
      'parentId': serializer.toJson<String?>(parentId),
      'unreadCount': serializer.toJson<int>(unreadCount),
      'totalCount': serializer.toJson<int>(totalCount),
      'isSubscribed': serializer.toJson<bool>(isSubscribed),
      'visible': serializer.toJson<bool>(visible),
      'syncEnabled': serializer.toJson<bool>(syncEnabled),
      'notificationsEnabled': serializer.toJson<bool>(notificationsEnabled),
      'unified': serializer.toJson<bool>(unified),
      'sortIndex': serializer.toJson<int>(sortIndex),
    };
  }

  Folder copyWith({
    String? id,
    String? accountId,
    String? remoteId,
    String? displayName,
    FolderType? folderType,
    Value<String?> parentId = const Value.absent(),
    int? unreadCount,
    int? totalCount,
    bool? isSubscribed,
    bool? visible,
    bool? syncEnabled,
    bool? notificationsEnabled,
    bool? unified,
    int? sortIndex,
  }) => Folder(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    remoteId: remoteId ?? this.remoteId,
    displayName: displayName ?? this.displayName,
    folderType: folderType ?? this.folderType,
    parentId: parentId.present ? parentId.value : this.parentId,
    unreadCount: unreadCount ?? this.unreadCount,
    totalCount: totalCount ?? this.totalCount,
    isSubscribed: isSubscribed ?? this.isSubscribed,
    visible: visible ?? this.visible,
    syncEnabled: syncEnabled ?? this.syncEnabled,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    unified: unified ?? this.unified,
    sortIndex: sortIndex ?? this.sortIndex,
  );
  Folder copyWithCompanion(FoldersCompanion data) {
    return Folder(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      folderType: data.folderType.present
          ? data.folderType.value
          : this.folderType,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      unreadCount: data.unreadCount.present
          ? data.unreadCount.value
          : this.unreadCount,
      totalCount: data.totalCount.present
          ? data.totalCount.value
          : this.totalCount,
      isSubscribed: data.isSubscribed.present
          ? data.isSubscribed.value
          : this.isSubscribed,
      visible: data.visible.present ? data.visible.value : this.visible,
      syncEnabled: data.syncEnabled.present
          ? data.syncEnabled.value
          : this.syncEnabled,
      notificationsEnabled: data.notificationsEnabled.present
          ? data.notificationsEnabled.value
          : this.notificationsEnabled,
      unified: data.unified.present ? data.unified.value : this.unified,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Folder(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('remoteId: $remoteId, ')
          ..write('displayName: $displayName, ')
          ..write('folderType: $folderType, ')
          ..write('parentId: $parentId, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('totalCount: $totalCount, ')
          ..write('isSubscribed: $isSubscribed, ')
          ..write('visible: $visible, ')
          ..write('syncEnabled: $syncEnabled, ')
          ..write('notificationsEnabled: $notificationsEnabled, ')
          ..write('unified: $unified, ')
          ..write('sortIndex: $sortIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    remoteId,
    displayName,
    folderType,
    parentId,
    unreadCount,
    totalCount,
    isSubscribed,
    visible,
    syncEnabled,
    notificationsEnabled,
    unified,
    sortIndex,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Folder &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.remoteId == this.remoteId &&
          other.displayName == this.displayName &&
          other.folderType == this.folderType &&
          other.parentId == this.parentId &&
          other.unreadCount == this.unreadCount &&
          other.totalCount == this.totalCount &&
          other.isSubscribed == this.isSubscribed &&
          other.visible == this.visible &&
          other.syncEnabled == this.syncEnabled &&
          other.notificationsEnabled == this.notificationsEnabled &&
          other.unified == this.unified &&
          other.sortIndex == this.sortIndex);
}

class FoldersCompanion extends UpdateCompanion<Folder> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<String> remoteId;
  final Value<String> displayName;
  final Value<FolderType> folderType;
  final Value<String?> parentId;
  final Value<int> unreadCount;
  final Value<int> totalCount;
  final Value<bool> isSubscribed;
  final Value<bool> visible;
  final Value<bool> syncEnabled;
  final Value<bool> notificationsEnabled;
  final Value<bool> unified;
  final Value<int> sortIndex;
  final Value<int> rowid;
  const FoldersCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.folderType = const Value.absent(),
    this.parentId = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.totalCount = const Value.absent(),
    this.isSubscribed = const Value.absent(),
    this.visible = const Value.absent(),
    this.syncEnabled = const Value.absent(),
    this.notificationsEnabled = const Value.absent(),
    this.unified = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FoldersCompanion.insert({
    required String id,
    required String accountId,
    required String remoteId,
    required String displayName,
    required FolderType folderType,
    this.parentId = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.totalCount = const Value.absent(),
    this.isSubscribed = const Value.absent(),
    this.visible = const Value.absent(),
    this.syncEnabled = const Value.absent(),
    this.notificationsEnabled = const Value.absent(),
    this.unified = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       remoteId = Value(remoteId),
       displayName = Value(displayName),
       folderType = Value(folderType);
  static Insertable<Folder> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? remoteId,
    Expression<String>? displayName,
    Expression<int>? folderType,
    Expression<String>? parentId,
    Expression<int>? unreadCount,
    Expression<int>? totalCount,
    Expression<bool>? isSubscribed,
    Expression<bool>? visible,
    Expression<bool>? syncEnabled,
    Expression<bool>? notificationsEnabled,
    Expression<bool>? unified,
    Expression<int>? sortIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (remoteId != null) 'remote_id': remoteId,
      if (displayName != null) 'display_name': displayName,
      if (folderType != null) 'folder_type': folderType,
      if (parentId != null) 'parent_id': parentId,
      if (unreadCount != null) 'unread_count': unreadCount,
      if (totalCount != null) 'total_count': totalCount,
      if (isSubscribed != null) 'is_subscribed': isSubscribed,
      if (visible != null) 'visible': visible,
      if (syncEnabled != null) 'sync_enabled': syncEnabled,
      if (notificationsEnabled != null)
        'notifications_enabled': notificationsEnabled,
      if (unified != null) 'unified': unified,
      if (sortIndex != null) 'sort_index': sortIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FoldersCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<String>? remoteId,
    Value<String>? displayName,
    Value<FolderType>? folderType,
    Value<String?>? parentId,
    Value<int>? unreadCount,
    Value<int>? totalCount,
    Value<bool>? isSubscribed,
    Value<bool>? visible,
    Value<bool>? syncEnabled,
    Value<bool>? notificationsEnabled,
    Value<bool>? unified,
    Value<int>? sortIndex,
    Value<int>? rowid,
  }) {
    return FoldersCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      remoteId: remoteId ?? this.remoteId,
      displayName: displayName ?? this.displayName,
      folderType: folderType ?? this.folderType,
      parentId: parentId ?? this.parentId,
      unreadCount: unreadCount ?? this.unreadCount,
      totalCount: totalCount ?? this.totalCount,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      visible: visible ?? this.visible,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      unified: unified ?? this.unified,
      sortIndex: sortIndex ?? this.sortIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (folderType.present) {
      map['folder_type'] = Variable<int>(
        $FoldersTable.$converterfolderType.toSql(folderType.value),
      );
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (unreadCount.present) {
      map['unread_count'] = Variable<int>(unreadCount.value);
    }
    if (totalCount.present) {
      map['total_count'] = Variable<int>(totalCount.value);
    }
    if (isSubscribed.present) {
      map['is_subscribed'] = Variable<bool>(isSubscribed.value);
    }
    if (visible.present) {
      map['visible'] = Variable<bool>(visible.value);
    }
    if (syncEnabled.present) {
      map['sync_enabled'] = Variable<bool>(syncEnabled.value);
    }
    if (notificationsEnabled.present) {
      map['notifications_enabled'] = Variable<bool>(notificationsEnabled.value);
    }
    if (unified.present) {
      map['unified'] = Variable<bool>(unified.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoldersCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('remoteId: $remoteId, ')
          ..write('displayName: $displayName, ')
          ..write('folderType: $folderType, ')
          ..write('parentId: $parentId, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('totalCount: $totalCount, ')
          ..write('isSubscribed: $isSubscribed, ')
          ..write('visible: $visible, ')
          ..write('syncEnabled: $syncEnabled, ')
          ..write('notificationsEnabled: $notificationsEnabled, ')
          ..write('unified: $unified, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages with TableInfo<$MessagesTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES folders (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _imapUidMeta = const VerificationMeta(
    'imapUid',
  );
  @override
  late final GeneratedColumn<int> imapUid = GeneratedColumn<int>(
    'imap_uid',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imapUidValidityMeta = const VerificationMeta(
    'imapUidValidity',
  );
  @override
  late final GeneratedColumn<int> imapUidValidity = GeneratedColumn<int>(
    'imap_uid_validity',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _graphMessageIdMeta = const VerificationMeta(
    'graphMessageId',
  );
  @override
  late final GeneratedColumn<String> graphMessageId = GeneratedColumn<String>(
    'graph_message_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gmailMessageIdMeta = const VerificationMeta(
    'gmailMessageId',
  );
  @override
  late final GeneratedColumn<String> gmailMessageId = GeneratedColumn<String>(
    'gmail_message_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _fromNameMeta = const VerificationMeta(
    'fromName',
  );
  @override
  late final GeneratedColumn<String> fromName = GeneratedColumn<String>(
    'from_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fromEmailMeta = const VerificationMeta(
    'fromEmail',
  );
  @override
  late final GeneratedColumn<String> fromEmail = GeneratedColumn<String>(
    'from_email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toRecipientsMeta = const VerificationMeta(
    'toRecipients',
  );
  @override
  late final GeneratedColumn<String> toRecipients = GeneratedColumn<String>(
    'to_recipients',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _ccRecipientsMeta = const VerificationMeta(
    'ccRecipients',
  );
  @override
  late final GeneratedColumn<String> ccRecipients = GeneratedColumn<String>(
    'cc_recipients',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _previewMeta = const VerificationMeta(
    'preview',
  );
  @override
  late final GeneratedColumn<String> preview = GeneratedColumn<String>(
    'preview',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _flagsBitmaskMeta = const VerificationMeta(
    'flagsBitmask',
  );
  @override
  late final GeneratedColumn<int> flagsBitmask = GeneratedColumn<int>(
    'flags_bitmask',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _hasAttachmentsMeta = const VerificationMeta(
    'hasAttachments',
  );
  @override
  late final GeneratedColumn<bool> hasAttachments = GeneratedColumn<bool>(
    'has_attachments',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_attachments" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _threadKeyMeta = const VerificationMeta(
    'threadKey',
  );
  @override
  late final GeneratedColumn<String> threadKey = GeneratedColumn<String>(
    'thread_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _messageIdHeaderMeta = const VerificationMeta(
    'messageIdHeader',
  );
  @override
  late final GeneratedColumn<String> messageIdHeader = GeneratedColumn<String>(
    'message_id_header',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _labelsMeta = const VerificationMeta('labels');
  @override
  late final GeneratedColumn<String> labels = GeneratedColumn<String>(
    'labels',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    folderId,
    imapUid,
    imapUidValidity,
    graphMessageId,
    gmailMessageId,
    subject,
    fromName,
    fromEmail,
    toRecipients,
    ccRecipients,
    date,
    preview,
    flagsBitmask,
    hasAttachments,
    threadKey,
    messageIdHeader,
    labels,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<Message> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_folderIdMeta);
    }
    if (data.containsKey('imap_uid')) {
      context.handle(
        _imapUidMeta,
        imapUid.isAcceptableOrUnknown(data['imap_uid']!, _imapUidMeta),
      );
    }
    if (data.containsKey('imap_uid_validity')) {
      context.handle(
        _imapUidValidityMeta,
        imapUidValidity.isAcceptableOrUnknown(
          data['imap_uid_validity']!,
          _imapUidValidityMeta,
        ),
      );
    }
    if (data.containsKey('graph_message_id')) {
      context.handle(
        _graphMessageIdMeta,
        graphMessageId.isAcceptableOrUnknown(
          data['graph_message_id']!,
          _graphMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('gmail_message_id')) {
      context.handle(
        _gmailMessageIdMeta,
        gmailMessageId.isAcceptableOrUnknown(
          data['gmail_message_id']!,
          _gmailMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    }
    if (data.containsKey('from_name')) {
      context.handle(
        _fromNameMeta,
        fromName.isAcceptableOrUnknown(data['from_name']!, _fromNameMeta),
      );
    }
    if (data.containsKey('from_email')) {
      context.handle(
        _fromEmailMeta,
        fromEmail.isAcceptableOrUnknown(data['from_email']!, _fromEmailMeta),
      );
    }
    if (data.containsKey('to_recipients')) {
      context.handle(
        _toRecipientsMeta,
        toRecipients.isAcceptableOrUnknown(
          data['to_recipients']!,
          _toRecipientsMeta,
        ),
      );
    }
    if (data.containsKey('cc_recipients')) {
      context.handle(
        _ccRecipientsMeta,
        ccRecipients.isAcceptableOrUnknown(
          data['cc_recipients']!,
          _ccRecipientsMeta,
        ),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('preview')) {
      context.handle(
        _previewMeta,
        preview.isAcceptableOrUnknown(data['preview']!, _previewMeta),
      );
    }
    if (data.containsKey('flags_bitmask')) {
      context.handle(
        _flagsBitmaskMeta,
        flagsBitmask.isAcceptableOrUnknown(
          data['flags_bitmask']!,
          _flagsBitmaskMeta,
        ),
      );
    }
    if (data.containsKey('has_attachments')) {
      context.handle(
        _hasAttachmentsMeta,
        hasAttachments.isAcceptableOrUnknown(
          data['has_attachments']!,
          _hasAttachmentsMeta,
        ),
      );
    }
    if (data.containsKey('thread_key')) {
      context.handle(
        _threadKeyMeta,
        threadKey.isAcceptableOrUnknown(data['thread_key']!, _threadKeyMeta),
      );
    }
    if (data.containsKey('message_id_header')) {
      context.handle(
        _messageIdHeaderMeta,
        messageIdHeader.isAcceptableOrUnknown(
          data['message_id_header']!,
          _messageIdHeaderMeta,
        ),
      );
    }
    if (data.containsKey('labels')) {
      context.handle(
        _labelsMeta,
        labels.isAcceptableOrUnknown(data['labels']!, _labelsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {folderId, imapUid},
    {accountId, graphMessageId},
    {accountId, gmailMessageId},
  ];
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      )!,
      imapUid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}imap_uid'],
      ),
      imapUidValidity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}imap_uid_validity'],
      ),
      graphMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}graph_message_id'],
      ),
      gmailMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gmail_message_id'],
      ),
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      )!,
      fromName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_name'],
      ),
      fromEmail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_email'],
      ),
      toRecipients: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_recipients'],
      )!,
      ccRecipients: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cc_recipients'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      preview: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preview'],
      )!,
      flagsBitmask: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}flags_bitmask'],
      )!,
      hasAttachments: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_attachments'],
      )!,
      threadKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thread_key'],
      ),
      messageIdHeader: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id_header'],
      ),
      labels: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}labels'],
      )!,
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class Message extends DataClass implements Insertable<Message> {
  /// 内部稳定主键（UUID）。UI/正文/附件均以此关联。
  final String id;
  final String accountId;
  final String folderId;

  /// IMAP：UID。
  final int? imapUid;

  /// IMAP：UIDVALIDITY（变更则整文件夹失效重同步）。
  final int? imapUidValidity;

  /// Graph：immutable message id。
  final String? graphMessageId;

  /// Gmail：REST API 的 message id（全邮箱唯一）。
  final String? gmailMessageId;
  final String subject;
  final String? fromName;
  final String? fromEmail;

  /// 收件人/抄送，JSON 数组字符串（[{name,email}]）。
  final String toRecipients;
  final String ccRecipients;
  final DateTime date;

  /// 预览片段。
  final String preview;

  /// 归一化标志位的位掩码（见 [MessageFlag]）。
  final int flagsBitmask;
  final bool hasAttachments;

  /// 线程键：IMAP 由 References/In-Reply-To 推导，Graph 用 conversationId。
  final String? threadKey;

  /// RFC822 Message-ID 头。
  final String? messageIdHeader;

  /// 后端独有标签（如 Gmail labels / Graph categories），JSON 数组字符串。
  final String labels;
  const Message({
    required this.id,
    required this.accountId,
    required this.folderId,
    this.imapUid,
    this.imapUidValidity,
    this.graphMessageId,
    this.gmailMessageId,
    required this.subject,
    this.fromName,
    this.fromEmail,
    required this.toRecipients,
    required this.ccRecipients,
    required this.date,
    required this.preview,
    required this.flagsBitmask,
    required this.hasAttachments,
    this.threadKey,
    this.messageIdHeader,
    required this.labels,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    map['folder_id'] = Variable<String>(folderId);
    if (!nullToAbsent || imapUid != null) {
      map['imap_uid'] = Variable<int>(imapUid);
    }
    if (!nullToAbsent || imapUidValidity != null) {
      map['imap_uid_validity'] = Variable<int>(imapUidValidity);
    }
    if (!nullToAbsent || graphMessageId != null) {
      map['graph_message_id'] = Variable<String>(graphMessageId);
    }
    if (!nullToAbsent || gmailMessageId != null) {
      map['gmail_message_id'] = Variable<String>(gmailMessageId);
    }
    map['subject'] = Variable<String>(subject);
    if (!nullToAbsent || fromName != null) {
      map['from_name'] = Variable<String>(fromName);
    }
    if (!nullToAbsent || fromEmail != null) {
      map['from_email'] = Variable<String>(fromEmail);
    }
    map['to_recipients'] = Variable<String>(toRecipients);
    map['cc_recipients'] = Variable<String>(ccRecipients);
    map['date'] = Variable<DateTime>(date);
    map['preview'] = Variable<String>(preview);
    map['flags_bitmask'] = Variable<int>(flagsBitmask);
    map['has_attachments'] = Variable<bool>(hasAttachments);
    if (!nullToAbsent || threadKey != null) {
      map['thread_key'] = Variable<String>(threadKey);
    }
    if (!nullToAbsent || messageIdHeader != null) {
      map['message_id_header'] = Variable<String>(messageIdHeader);
    }
    map['labels'] = Variable<String>(labels);
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      accountId: Value(accountId),
      folderId: Value(folderId),
      imapUid: imapUid == null && nullToAbsent
          ? const Value.absent()
          : Value(imapUid),
      imapUidValidity: imapUidValidity == null && nullToAbsent
          ? const Value.absent()
          : Value(imapUidValidity),
      graphMessageId: graphMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(graphMessageId),
      gmailMessageId: gmailMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(gmailMessageId),
      subject: Value(subject),
      fromName: fromName == null && nullToAbsent
          ? const Value.absent()
          : Value(fromName),
      fromEmail: fromEmail == null && nullToAbsent
          ? const Value.absent()
          : Value(fromEmail),
      toRecipients: Value(toRecipients),
      ccRecipients: Value(ccRecipients),
      date: Value(date),
      preview: Value(preview),
      flagsBitmask: Value(flagsBitmask),
      hasAttachments: Value(hasAttachments),
      threadKey: threadKey == null && nullToAbsent
          ? const Value.absent()
          : Value(threadKey),
      messageIdHeader: messageIdHeader == null && nullToAbsent
          ? const Value.absent()
          : Value(messageIdHeader),
      labels: Value(labels),
    );
  }

  factory Message.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      folderId: serializer.fromJson<String>(json['folderId']),
      imapUid: serializer.fromJson<int?>(json['imapUid']),
      imapUidValidity: serializer.fromJson<int?>(json['imapUidValidity']),
      graphMessageId: serializer.fromJson<String?>(json['graphMessageId']),
      gmailMessageId: serializer.fromJson<String?>(json['gmailMessageId']),
      subject: serializer.fromJson<String>(json['subject']),
      fromName: serializer.fromJson<String?>(json['fromName']),
      fromEmail: serializer.fromJson<String?>(json['fromEmail']),
      toRecipients: serializer.fromJson<String>(json['toRecipients']),
      ccRecipients: serializer.fromJson<String>(json['ccRecipients']),
      date: serializer.fromJson<DateTime>(json['date']),
      preview: serializer.fromJson<String>(json['preview']),
      flagsBitmask: serializer.fromJson<int>(json['flagsBitmask']),
      hasAttachments: serializer.fromJson<bool>(json['hasAttachments']),
      threadKey: serializer.fromJson<String?>(json['threadKey']),
      messageIdHeader: serializer.fromJson<String?>(json['messageIdHeader']),
      labels: serializer.fromJson<String>(json['labels']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'folderId': serializer.toJson<String>(folderId),
      'imapUid': serializer.toJson<int?>(imapUid),
      'imapUidValidity': serializer.toJson<int?>(imapUidValidity),
      'graphMessageId': serializer.toJson<String?>(graphMessageId),
      'gmailMessageId': serializer.toJson<String?>(gmailMessageId),
      'subject': serializer.toJson<String>(subject),
      'fromName': serializer.toJson<String?>(fromName),
      'fromEmail': serializer.toJson<String?>(fromEmail),
      'toRecipients': serializer.toJson<String>(toRecipients),
      'ccRecipients': serializer.toJson<String>(ccRecipients),
      'date': serializer.toJson<DateTime>(date),
      'preview': serializer.toJson<String>(preview),
      'flagsBitmask': serializer.toJson<int>(flagsBitmask),
      'hasAttachments': serializer.toJson<bool>(hasAttachments),
      'threadKey': serializer.toJson<String?>(threadKey),
      'messageIdHeader': serializer.toJson<String?>(messageIdHeader),
      'labels': serializer.toJson<String>(labels),
    };
  }

  Message copyWith({
    String? id,
    String? accountId,
    String? folderId,
    Value<int?> imapUid = const Value.absent(),
    Value<int?> imapUidValidity = const Value.absent(),
    Value<String?> graphMessageId = const Value.absent(),
    Value<String?> gmailMessageId = const Value.absent(),
    String? subject,
    Value<String?> fromName = const Value.absent(),
    Value<String?> fromEmail = const Value.absent(),
    String? toRecipients,
    String? ccRecipients,
    DateTime? date,
    String? preview,
    int? flagsBitmask,
    bool? hasAttachments,
    Value<String?> threadKey = const Value.absent(),
    Value<String?> messageIdHeader = const Value.absent(),
    String? labels,
  }) => Message(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    folderId: folderId ?? this.folderId,
    imapUid: imapUid.present ? imapUid.value : this.imapUid,
    imapUidValidity: imapUidValidity.present
        ? imapUidValidity.value
        : this.imapUidValidity,
    graphMessageId: graphMessageId.present
        ? graphMessageId.value
        : this.graphMessageId,
    gmailMessageId: gmailMessageId.present
        ? gmailMessageId.value
        : this.gmailMessageId,
    subject: subject ?? this.subject,
    fromName: fromName.present ? fromName.value : this.fromName,
    fromEmail: fromEmail.present ? fromEmail.value : this.fromEmail,
    toRecipients: toRecipients ?? this.toRecipients,
    ccRecipients: ccRecipients ?? this.ccRecipients,
    date: date ?? this.date,
    preview: preview ?? this.preview,
    flagsBitmask: flagsBitmask ?? this.flagsBitmask,
    hasAttachments: hasAttachments ?? this.hasAttachments,
    threadKey: threadKey.present ? threadKey.value : this.threadKey,
    messageIdHeader: messageIdHeader.present
        ? messageIdHeader.value
        : this.messageIdHeader,
    labels: labels ?? this.labels,
  );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      imapUid: data.imapUid.present ? data.imapUid.value : this.imapUid,
      imapUidValidity: data.imapUidValidity.present
          ? data.imapUidValidity.value
          : this.imapUidValidity,
      graphMessageId: data.graphMessageId.present
          ? data.graphMessageId.value
          : this.graphMessageId,
      gmailMessageId: data.gmailMessageId.present
          ? data.gmailMessageId.value
          : this.gmailMessageId,
      subject: data.subject.present ? data.subject.value : this.subject,
      fromName: data.fromName.present ? data.fromName.value : this.fromName,
      fromEmail: data.fromEmail.present ? data.fromEmail.value : this.fromEmail,
      toRecipients: data.toRecipients.present
          ? data.toRecipients.value
          : this.toRecipients,
      ccRecipients: data.ccRecipients.present
          ? data.ccRecipients.value
          : this.ccRecipients,
      date: data.date.present ? data.date.value : this.date,
      preview: data.preview.present ? data.preview.value : this.preview,
      flagsBitmask: data.flagsBitmask.present
          ? data.flagsBitmask.value
          : this.flagsBitmask,
      hasAttachments: data.hasAttachments.present
          ? data.hasAttachments.value
          : this.hasAttachments,
      threadKey: data.threadKey.present ? data.threadKey.value : this.threadKey,
      messageIdHeader: data.messageIdHeader.present
          ? data.messageIdHeader.value
          : this.messageIdHeader,
      labels: data.labels.present ? data.labels.value : this.labels,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('folderId: $folderId, ')
          ..write('imapUid: $imapUid, ')
          ..write('imapUidValidity: $imapUidValidity, ')
          ..write('graphMessageId: $graphMessageId, ')
          ..write('gmailMessageId: $gmailMessageId, ')
          ..write('subject: $subject, ')
          ..write('fromName: $fromName, ')
          ..write('fromEmail: $fromEmail, ')
          ..write('toRecipients: $toRecipients, ')
          ..write('ccRecipients: $ccRecipients, ')
          ..write('date: $date, ')
          ..write('preview: $preview, ')
          ..write('flagsBitmask: $flagsBitmask, ')
          ..write('hasAttachments: $hasAttachments, ')
          ..write('threadKey: $threadKey, ')
          ..write('messageIdHeader: $messageIdHeader, ')
          ..write('labels: $labels')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    folderId,
    imapUid,
    imapUidValidity,
    graphMessageId,
    gmailMessageId,
    subject,
    fromName,
    fromEmail,
    toRecipients,
    ccRecipients,
    date,
    preview,
    flagsBitmask,
    hasAttachments,
    threadKey,
    messageIdHeader,
    labels,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.folderId == this.folderId &&
          other.imapUid == this.imapUid &&
          other.imapUidValidity == this.imapUidValidity &&
          other.graphMessageId == this.graphMessageId &&
          other.gmailMessageId == this.gmailMessageId &&
          other.subject == this.subject &&
          other.fromName == this.fromName &&
          other.fromEmail == this.fromEmail &&
          other.toRecipients == this.toRecipients &&
          other.ccRecipients == this.ccRecipients &&
          other.date == this.date &&
          other.preview == this.preview &&
          other.flagsBitmask == this.flagsBitmask &&
          other.hasAttachments == this.hasAttachments &&
          other.threadKey == this.threadKey &&
          other.messageIdHeader == this.messageIdHeader &&
          other.labels == this.labels);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<String> folderId;
  final Value<int?> imapUid;
  final Value<int?> imapUidValidity;
  final Value<String?> graphMessageId;
  final Value<String?> gmailMessageId;
  final Value<String> subject;
  final Value<String?> fromName;
  final Value<String?> fromEmail;
  final Value<String> toRecipients;
  final Value<String> ccRecipients;
  final Value<DateTime> date;
  final Value<String> preview;
  final Value<int> flagsBitmask;
  final Value<bool> hasAttachments;
  final Value<String?> threadKey;
  final Value<String?> messageIdHeader;
  final Value<String> labels;
  final Value<int> rowid;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.folderId = const Value.absent(),
    this.imapUid = const Value.absent(),
    this.imapUidValidity = const Value.absent(),
    this.graphMessageId = const Value.absent(),
    this.gmailMessageId = const Value.absent(),
    this.subject = const Value.absent(),
    this.fromName = const Value.absent(),
    this.fromEmail = const Value.absent(),
    this.toRecipients = const Value.absent(),
    this.ccRecipients = const Value.absent(),
    this.date = const Value.absent(),
    this.preview = const Value.absent(),
    this.flagsBitmask = const Value.absent(),
    this.hasAttachments = const Value.absent(),
    this.threadKey = const Value.absent(),
    this.messageIdHeader = const Value.absent(),
    this.labels = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String id,
    required String accountId,
    required String folderId,
    this.imapUid = const Value.absent(),
    this.imapUidValidity = const Value.absent(),
    this.graphMessageId = const Value.absent(),
    this.gmailMessageId = const Value.absent(),
    this.subject = const Value.absent(),
    this.fromName = const Value.absent(),
    this.fromEmail = const Value.absent(),
    this.toRecipients = const Value.absent(),
    this.ccRecipients = const Value.absent(),
    required DateTime date,
    this.preview = const Value.absent(),
    this.flagsBitmask = const Value.absent(),
    this.hasAttachments = const Value.absent(),
    this.threadKey = const Value.absent(),
    this.messageIdHeader = const Value.absent(),
    this.labels = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       folderId = Value(folderId),
       date = Value(date);
  static Insertable<Message> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? folderId,
    Expression<int>? imapUid,
    Expression<int>? imapUidValidity,
    Expression<String>? graphMessageId,
    Expression<String>? gmailMessageId,
    Expression<String>? subject,
    Expression<String>? fromName,
    Expression<String>? fromEmail,
    Expression<String>? toRecipients,
    Expression<String>? ccRecipients,
    Expression<DateTime>? date,
    Expression<String>? preview,
    Expression<int>? flagsBitmask,
    Expression<bool>? hasAttachments,
    Expression<String>? threadKey,
    Expression<String>? messageIdHeader,
    Expression<String>? labels,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (folderId != null) 'folder_id': folderId,
      if (imapUid != null) 'imap_uid': imapUid,
      if (imapUidValidity != null) 'imap_uid_validity': imapUidValidity,
      if (graphMessageId != null) 'graph_message_id': graphMessageId,
      if (gmailMessageId != null) 'gmail_message_id': gmailMessageId,
      if (subject != null) 'subject': subject,
      if (fromName != null) 'from_name': fromName,
      if (fromEmail != null) 'from_email': fromEmail,
      if (toRecipients != null) 'to_recipients': toRecipients,
      if (ccRecipients != null) 'cc_recipients': ccRecipients,
      if (date != null) 'date': date,
      if (preview != null) 'preview': preview,
      if (flagsBitmask != null) 'flags_bitmask': flagsBitmask,
      if (hasAttachments != null) 'has_attachments': hasAttachments,
      if (threadKey != null) 'thread_key': threadKey,
      if (messageIdHeader != null) 'message_id_header': messageIdHeader,
      if (labels != null) 'labels': labels,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<String>? folderId,
    Value<int?>? imapUid,
    Value<int?>? imapUidValidity,
    Value<String?>? graphMessageId,
    Value<String?>? gmailMessageId,
    Value<String>? subject,
    Value<String?>? fromName,
    Value<String?>? fromEmail,
    Value<String>? toRecipients,
    Value<String>? ccRecipients,
    Value<DateTime>? date,
    Value<String>? preview,
    Value<int>? flagsBitmask,
    Value<bool>? hasAttachments,
    Value<String?>? threadKey,
    Value<String?>? messageIdHeader,
    Value<String>? labels,
    Value<int>? rowid,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      folderId: folderId ?? this.folderId,
      imapUid: imapUid ?? this.imapUid,
      imapUidValidity: imapUidValidity ?? this.imapUidValidity,
      graphMessageId: graphMessageId ?? this.graphMessageId,
      gmailMessageId: gmailMessageId ?? this.gmailMessageId,
      subject: subject ?? this.subject,
      fromName: fromName ?? this.fromName,
      fromEmail: fromEmail ?? this.fromEmail,
      toRecipients: toRecipients ?? this.toRecipients,
      ccRecipients: ccRecipients ?? this.ccRecipients,
      date: date ?? this.date,
      preview: preview ?? this.preview,
      flagsBitmask: flagsBitmask ?? this.flagsBitmask,
      hasAttachments: hasAttachments ?? this.hasAttachments,
      threadKey: threadKey ?? this.threadKey,
      messageIdHeader: messageIdHeader ?? this.messageIdHeader,
      labels: labels ?? this.labels,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (imapUid.present) {
      map['imap_uid'] = Variable<int>(imapUid.value);
    }
    if (imapUidValidity.present) {
      map['imap_uid_validity'] = Variable<int>(imapUidValidity.value);
    }
    if (graphMessageId.present) {
      map['graph_message_id'] = Variable<String>(graphMessageId.value);
    }
    if (gmailMessageId.present) {
      map['gmail_message_id'] = Variable<String>(gmailMessageId.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (fromName.present) {
      map['from_name'] = Variable<String>(fromName.value);
    }
    if (fromEmail.present) {
      map['from_email'] = Variable<String>(fromEmail.value);
    }
    if (toRecipients.present) {
      map['to_recipients'] = Variable<String>(toRecipients.value);
    }
    if (ccRecipients.present) {
      map['cc_recipients'] = Variable<String>(ccRecipients.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (preview.present) {
      map['preview'] = Variable<String>(preview.value);
    }
    if (flagsBitmask.present) {
      map['flags_bitmask'] = Variable<int>(flagsBitmask.value);
    }
    if (hasAttachments.present) {
      map['has_attachments'] = Variable<bool>(hasAttachments.value);
    }
    if (threadKey.present) {
      map['thread_key'] = Variable<String>(threadKey.value);
    }
    if (messageIdHeader.present) {
      map['message_id_header'] = Variable<String>(messageIdHeader.value);
    }
    if (labels.present) {
      map['labels'] = Variable<String>(labels.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('folderId: $folderId, ')
          ..write('imapUid: $imapUid, ')
          ..write('imapUidValidity: $imapUidValidity, ')
          ..write('graphMessageId: $graphMessageId, ')
          ..write('gmailMessageId: $gmailMessageId, ')
          ..write('subject: $subject, ')
          ..write('fromName: $fromName, ')
          ..write('fromEmail: $fromEmail, ')
          ..write('toRecipients: $toRecipients, ')
          ..write('ccRecipients: $ccRecipients, ')
          ..write('date: $date, ')
          ..write('preview: $preview, ')
          ..write('flagsBitmask: $flagsBitmask, ')
          ..write('hasAttachments: $hasAttachments, ')
          ..write('threadKey: $threadKey, ')
          ..write('messageIdHeader: $messageIdHeader, ')
          ..write('labels: $labels, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessageBodiesTable extends MessageBodies
    with TableInfo<$MessageBodiesTable, MessageBody> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessageBodiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES messages (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _plainTextMeta = const VerificationMeta(
    'plainText',
  );
  @override
  late final GeneratedColumn<String> plainText = GeneratedColumn<String>(
    'plain_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _htmlBodyMeta = const VerificationMeta(
    'htmlBody',
  );
  @override
  late final GeneratedColumn<String> htmlBody = GeneratedColumn<String>(
    'html_body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<BodyFetchState, int> fetchState =
      GeneratedColumn<int>(
        'fetch_state',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: Constant(BodyFetchState.notDownloaded.index),
      ).withConverter<BodyFetchState>($MessageBodiesTable.$converterfetchState);
  static const VerificationMeta _attachmentsMetaMeta = const VerificationMeta(
    'attachmentsMeta',
  );
  @override
  late final GeneratedColumn<String> attachmentsMeta = GeneratedColumn<String>(
    'attachments_meta',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    messageId,
    plainText,
    htmlBody,
    fetchState,
    attachmentsMeta,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'message_bodies';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageBody> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('plain_text')) {
      context.handle(
        _plainTextMeta,
        plainText.isAcceptableOrUnknown(data['plain_text']!, _plainTextMeta),
      );
    }
    if (data.containsKey('html_body')) {
      context.handle(
        _htmlBodyMeta,
        htmlBody.isAcceptableOrUnknown(data['html_body']!, _htmlBodyMeta),
      );
    }
    if (data.containsKey('attachments_meta')) {
      context.handle(
        _attachmentsMetaMeta,
        attachmentsMeta.isAcceptableOrUnknown(
          data['attachments_meta']!,
          _attachmentsMetaMeta,
        ),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId};
  @override
  MessageBody map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageBody(
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      plainText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plain_text'],
      ),
      htmlBody: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}html_body'],
      ),
      fetchState: $MessageBodiesTable.$converterfetchState.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}fetch_state'],
        )!,
      ),
      attachmentsMeta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachments_meta'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      ),
    );
  }

  @override
  $MessageBodiesTable createAlias(String alias) {
    return $MessageBodiesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<BodyFetchState, int, int> $converterfetchState =
      const EnumIndexConverter<BodyFetchState>(BodyFetchState.values);
}

class MessageBody extends DataClass implements Insertable<MessageBody> {
  final String messageId;

  /// 纯文本正文。
  final String? plainText;

  /// HTML 正文。
  final String? htmlBody;

  /// 下载状态。
  final BodyFetchState fetchState;

  /// 附件元数据 JSON 数组（[{partId,filename,mimeType,size,isInline,contentId,localPath}]）。
  /// 实际字节落文件系统，见 FileStore。
  final String attachmentsMeta;
  final DateTime? fetchedAt;
  const MessageBody({
    required this.messageId,
    this.plainText,
    this.htmlBody,
    required this.fetchState,
    required this.attachmentsMeta,
    this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<String>(messageId);
    if (!nullToAbsent || plainText != null) {
      map['plain_text'] = Variable<String>(plainText);
    }
    if (!nullToAbsent || htmlBody != null) {
      map['html_body'] = Variable<String>(htmlBody);
    }
    {
      map['fetch_state'] = Variable<int>(
        $MessageBodiesTable.$converterfetchState.toSql(fetchState),
      );
    }
    map['attachments_meta'] = Variable<String>(attachmentsMeta);
    if (!nullToAbsent || fetchedAt != null) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt);
    }
    return map;
  }

  MessageBodiesCompanion toCompanion(bool nullToAbsent) {
    return MessageBodiesCompanion(
      messageId: Value(messageId),
      plainText: plainText == null && nullToAbsent
          ? const Value.absent()
          : Value(plainText),
      htmlBody: htmlBody == null && nullToAbsent
          ? const Value.absent()
          : Value(htmlBody),
      fetchState: Value(fetchState),
      attachmentsMeta: Value(attachmentsMeta),
      fetchedAt: fetchedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(fetchedAt),
    );
  }

  factory MessageBody.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageBody(
      messageId: serializer.fromJson<String>(json['messageId']),
      plainText: serializer.fromJson<String?>(json['plainText']),
      htmlBody: serializer.fromJson<String?>(json['htmlBody']),
      fetchState: $MessageBodiesTable.$converterfetchState.fromJson(
        serializer.fromJson<int>(json['fetchState']),
      ),
      attachmentsMeta: serializer.fromJson<String>(json['attachmentsMeta']),
      fetchedAt: serializer.fromJson<DateTime?>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'messageId': serializer.toJson<String>(messageId),
      'plainText': serializer.toJson<String?>(plainText),
      'htmlBody': serializer.toJson<String?>(htmlBody),
      'fetchState': serializer.toJson<int>(
        $MessageBodiesTable.$converterfetchState.toJson(fetchState),
      ),
      'attachmentsMeta': serializer.toJson<String>(attachmentsMeta),
      'fetchedAt': serializer.toJson<DateTime?>(fetchedAt),
    };
  }

  MessageBody copyWith({
    String? messageId,
    Value<String?> plainText = const Value.absent(),
    Value<String?> htmlBody = const Value.absent(),
    BodyFetchState? fetchState,
    String? attachmentsMeta,
    Value<DateTime?> fetchedAt = const Value.absent(),
  }) => MessageBody(
    messageId: messageId ?? this.messageId,
    plainText: plainText.present ? plainText.value : this.plainText,
    htmlBody: htmlBody.present ? htmlBody.value : this.htmlBody,
    fetchState: fetchState ?? this.fetchState,
    attachmentsMeta: attachmentsMeta ?? this.attachmentsMeta,
    fetchedAt: fetchedAt.present ? fetchedAt.value : this.fetchedAt,
  );
  MessageBody copyWithCompanion(MessageBodiesCompanion data) {
    return MessageBody(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      plainText: data.plainText.present ? data.plainText.value : this.plainText,
      htmlBody: data.htmlBody.present ? data.htmlBody.value : this.htmlBody,
      fetchState: data.fetchState.present
          ? data.fetchState.value
          : this.fetchState,
      attachmentsMeta: data.attachmentsMeta.present
          ? data.attachmentsMeta.value
          : this.attachmentsMeta,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageBody(')
          ..write('messageId: $messageId, ')
          ..write('plainText: $plainText, ')
          ..write('htmlBody: $htmlBody, ')
          ..write('fetchState: $fetchState, ')
          ..write('attachmentsMeta: $attachmentsMeta, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    messageId,
    plainText,
    htmlBody,
    fetchState,
    attachmentsMeta,
    fetchedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageBody &&
          other.messageId == this.messageId &&
          other.plainText == this.plainText &&
          other.htmlBody == this.htmlBody &&
          other.fetchState == this.fetchState &&
          other.attachmentsMeta == this.attachmentsMeta &&
          other.fetchedAt == this.fetchedAt);
}

class MessageBodiesCompanion extends UpdateCompanion<MessageBody> {
  final Value<String> messageId;
  final Value<String?> plainText;
  final Value<String?> htmlBody;
  final Value<BodyFetchState> fetchState;
  final Value<String> attachmentsMeta;
  final Value<DateTime?> fetchedAt;
  final Value<int> rowid;
  const MessageBodiesCompanion({
    this.messageId = const Value.absent(),
    this.plainText = const Value.absent(),
    this.htmlBody = const Value.absent(),
    this.fetchState = const Value.absent(),
    this.attachmentsMeta = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessageBodiesCompanion.insert({
    required String messageId,
    this.plainText = const Value.absent(),
    this.htmlBody = const Value.absent(),
    this.fetchState = const Value.absent(),
    this.attachmentsMeta = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : messageId = Value(messageId);
  static Insertable<MessageBody> custom({
    Expression<String>? messageId,
    Expression<String>? plainText,
    Expression<String>? htmlBody,
    Expression<int>? fetchState,
    Expression<String>? attachmentsMeta,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'message_id': messageId,
      if (plainText != null) 'plain_text': plainText,
      if (htmlBody != null) 'html_body': htmlBody,
      if (fetchState != null) 'fetch_state': fetchState,
      if (attachmentsMeta != null) 'attachments_meta': attachmentsMeta,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessageBodiesCompanion copyWith({
    Value<String>? messageId,
    Value<String?>? plainText,
    Value<String?>? htmlBody,
    Value<BodyFetchState>? fetchState,
    Value<String>? attachmentsMeta,
    Value<DateTime?>? fetchedAt,
    Value<int>? rowid,
  }) {
    return MessageBodiesCompanion(
      messageId: messageId ?? this.messageId,
      plainText: plainText ?? this.plainText,
      htmlBody: htmlBody ?? this.htmlBody,
      fetchState: fetchState ?? this.fetchState,
      attachmentsMeta: attachmentsMeta ?? this.attachmentsMeta,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (plainText.present) {
      map['plain_text'] = Variable<String>(plainText.value);
    }
    if (htmlBody.present) {
      map['html_body'] = Variable<String>(htmlBody.value);
    }
    if (fetchState.present) {
      map['fetch_state'] = Variable<int>(
        $MessageBodiesTable.$converterfetchState.toSql(fetchState.value),
      );
    }
    if (attachmentsMeta.present) {
      map['attachments_meta'] = Variable<String>(attachmentsMeta.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessageBodiesCompanion(')
          ..write('messageId: $messageId, ')
          ..write('plainText: $plainText, ')
          ..write('htmlBody: $htmlBody, ')
          ..write('fetchState: $fetchState, ')
          ..write('attachmentsMeta: $attachmentsMeta, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStatesTable extends SyncStates
    with TableInfo<$SyncStatesTable, SyncState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES folders (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _uidNextMeta = const VerificationMeta(
    'uidNext',
  );
  @override
  late final GeneratedColumn<int> uidNext = GeneratedColumn<int>(
    'uid_next',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _uidValidityMeta = const VerificationMeta(
    'uidValidity',
  );
  @override
  late final GeneratedColumn<int> uidValidity = GeneratedColumn<int>(
    'uid_validity',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _highestModSeqMeta = const VerificationMeta(
    'highestModSeq',
  );
  @override
  late final GeneratedColumn<int> highestModSeq = GeneratedColumn<int>(
    'highest_mod_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deltaLinkMeta = const VerificationMeta(
    'deltaLink',
  );
  @override
  late final GeneratedColumn<String> deltaLink = GeneratedColumn<String>(
    'delta_link',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncAtMeta = const VerificationMeta(
    'lastSyncAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncAt = GeneratedColumn<DateTime>(
    'last_sync_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backfillCursorMeta = const VerificationMeta(
    'backfillCursor',
  );
  @override
  late final GeneratedColumn<String> backfillCursor = GeneratedColumn<String>(
    'backfill_cursor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backfillDoneMeta = const VerificationMeta(
    'backfillDone',
  );
  @override
  late final GeneratedColumn<bool> backfillDone = GeneratedColumn<bool>(
    'backfill_done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("backfill_done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    folderId,
    uidNext,
    uidValidity,
    highestModSeq,
    deltaLink,
    lastSyncAt,
    backfillCursor,
    backfillDone,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_folderIdMeta);
    }
    if (data.containsKey('uid_next')) {
      context.handle(
        _uidNextMeta,
        uidNext.isAcceptableOrUnknown(data['uid_next']!, _uidNextMeta),
      );
    }
    if (data.containsKey('uid_validity')) {
      context.handle(
        _uidValidityMeta,
        uidValidity.isAcceptableOrUnknown(
          data['uid_validity']!,
          _uidValidityMeta,
        ),
      );
    }
    if (data.containsKey('highest_mod_seq')) {
      context.handle(
        _highestModSeqMeta,
        highestModSeq.isAcceptableOrUnknown(
          data['highest_mod_seq']!,
          _highestModSeqMeta,
        ),
      );
    }
    if (data.containsKey('delta_link')) {
      context.handle(
        _deltaLinkMeta,
        deltaLink.isAcceptableOrUnknown(data['delta_link']!, _deltaLinkMeta),
      );
    }
    if (data.containsKey('last_sync_at')) {
      context.handle(
        _lastSyncAtMeta,
        lastSyncAt.isAcceptableOrUnknown(
          data['last_sync_at']!,
          _lastSyncAtMeta,
        ),
      );
    }
    if (data.containsKey('backfill_cursor')) {
      context.handle(
        _backfillCursorMeta,
        backfillCursor.isAcceptableOrUnknown(
          data['backfill_cursor']!,
          _backfillCursorMeta,
        ),
      );
    }
    if (data.containsKey('backfill_done')) {
      context.handle(
        _backfillDoneMeta,
        backfillDone.isAcceptableOrUnknown(
          data['backfill_done']!,
          _backfillDoneMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {folderId};
  @override
  SyncState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncState(
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      )!,
      uidNext: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}uid_next'],
      ),
      uidValidity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}uid_validity'],
      ),
      highestModSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}highest_mod_seq'],
      ),
      deltaLink: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}delta_link'],
      ),
      lastSyncAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_sync_at'],
      ),
      backfillCursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backfill_cursor'],
      ),
      backfillDone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}backfill_done'],
      )!,
    );
  }

  @override
  $SyncStatesTable createAlias(String alias) {
    return $SyncStatesTable(attachedDatabase, alias);
  }
}

class SyncState extends DataClass implements Insertable<SyncState> {
  final String folderId;
  final int? uidNext;
  final int? uidValidity;

  /// CONDSTORE HIGHESTMODSEQ（增量取标志变更）。
  final int? highestModSeq;

  /// delta query 返回的 @odata.deltaLink，下次只取增量。
  final String? deltaLink;
  final DateTime? lastSyncAt;

  /// 下一页更旧邮件的游标（Gmail pageToken / Graph @odata.nextLink）；null 表示尚未回填。
  final String? backfillCursor;

  /// 是否已回填到底（再无更旧邮件）。
  final bool backfillDone;
  const SyncState({
    required this.folderId,
    this.uidNext,
    this.uidValidity,
    this.highestModSeq,
    this.deltaLink,
    this.lastSyncAt,
    this.backfillCursor,
    required this.backfillDone,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['folder_id'] = Variable<String>(folderId);
    if (!nullToAbsent || uidNext != null) {
      map['uid_next'] = Variable<int>(uidNext);
    }
    if (!nullToAbsent || uidValidity != null) {
      map['uid_validity'] = Variable<int>(uidValidity);
    }
    if (!nullToAbsent || highestModSeq != null) {
      map['highest_mod_seq'] = Variable<int>(highestModSeq);
    }
    if (!nullToAbsent || deltaLink != null) {
      map['delta_link'] = Variable<String>(deltaLink);
    }
    if (!nullToAbsent || lastSyncAt != null) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt);
    }
    if (!nullToAbsent || backfillCursor != null) {
      map['backfill_cursor'] = Variable<String>(backfillCursor);
    }
    map['backfill_done'] = Variable<bool>(backfillDone);
    return map;
  }

  SyncStatesCompanion toCompanion(bool nullToAbsent) {
    return SyncStatesCompanion(
      folderId: Value(folderId),
      uidNext: uidNext == null && nullToAbsent
          ? const Value.absent()
          : Value(uidNext),
      uidValidity: uidValidity == null && nullToAbsent
          ? const Value.absent()
          : Value(uidValidity),
      highestModSeq: highestModSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(highestModSeq),
      deltaLink: deltaLink == null && nullToAbsent
          ? const Value.absent()
          : Value(deltaLink),
      lastSyncAt: lastSyncAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncAt),
      backfillCursor: backfillCursor == null && nullToAbsent
          ? const Value.absent()
          : Value(backfillCursor),
      backfillDone: Value(backfillDone),
    );
  }

  factory SyncState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncState(
      folderId: serializer.fromJson<String>(json['folderId']),
      uidNext: serializer.fromJson<int?>(json['uidNext']),
      uidValidity: serializer.fromJson<int?>(json['uidValidity']),
      highestModSeq: serializer.fromJson<int?>(json['highestModSeq']),
      deltaLink: serializer.fromJson<String?>(json['deltaLink']),
      lastSyncAt: serializer.fromJson<DateTime?>(json['lastSyncAt']),
      backfillCursor: serializer.fromJson<String?>(json['backfillCursor']),
      backfillDone: serializer.fromJson<bool>(json['backfillDone']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'folderId': serializer.toJson<String>(folderId),
      'uidNext': serializer.toJson<int?>(uidNext),
      'uidValidity': serializer.toJson<int?>(uidValidity),
      'highestModSeq': serializer.toJson<int?>(highestModSeq),
      'deltaLink': serializer.toJson<String?>(deltaLink),
      'lastSyncAt': serializer.toJson<DateTime?>(lastSyncAt),
      'backfillCursor': serializer.toJson<String?>(backfillCursor),
      'backfillDone': serializer.toJson<bool>(backfillDone),
    };
  }

  SyncState copyWith({
    String? folderId,
    Value<int?> uidNext = const Value.absent(),
    Value<int?> uidValidity = const Value.absent(),
    Value<int?> highestModSeq = const Value.absent(),
    Value<String?> deltaLink = const Value.absent(),
    Value<DateTime?> lastSyncAt = const Value.absent(),
    Value<String?> backfillCursor = const Value.absent(),
    bool? backfillDone,
  }) => SyncState(
    folderId: folderId ?? this.folderId,
    uidNext: uidNext.present ? uidNext.value : this.uidNext,
    uidValidity: uidValidity.present ? uidValidity.value : this.uidValidity,
    highestModSeq: highestModSeq.present
        ? highestModSeq.value
        : this.highestModSeq,
    deltaLink: deltaLink.present ? deltaLink.value : this.deltaLink,
    lastSyncAt: lastSyncAt.present ? lastSyncAt.value : this.lastSyncAt,
    backfillCursor: backfillCursor.present
        ? backfillCursor.value
        : this.backfillCursor,
    backfillDone: backfillDone ?? this.backfillDone,
  );
  SyncState copyWithCompanion(SyncStatesCompanion data) {
    return SyncState(
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      uidNext: data.uidNext.present ? data.uidNext.value : this.uidNext,
      uidValidity: data.uidValidity.present
          ? data.uidValidity.value
          : this.uidValidity,
      highestModSeq: data.highestModSeq.present
          ? data.highestModSeq.value
          : this.highestModSeq,
      deltaLink: data.deltaLink.present ? data.deltaLink.value : this.deltaLink,
      lastSyncAt: data.lastSyncAt.present
          ? data.lastSyncAt.value
          : this.lastSyncAt,
      backfillCursor: data.backfillCursor.present
          ? data.backfillCursor.value
          : this.backfillCursor,
      backfillDone: data.backfillDone.present
          ? data.backfillDone.value
          : this.backfillDone,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncState(')
          ..write('folderId: $folderId, ')
          ..write('uidNext: $uidNext, ')
          ..write('uidValidity: $uidValidity, ')
          ..write('highestModSeq: $highestModSeq, ')
          ..write('deltaLink: $deltaLink, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('backfillCursor: $backfillCursor, ')
          ..write('backfillDone: $backfillDone')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    folderId,
    uidNext,
    uidValidity,
    highestModSeq,
    deltaLink,
    lastSyncAt,
    backfillCursor,
    backfillDone,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncState &&
          other.folderId == this.folderId &&
          other.uidNext == this.uidNext &&
          other.uidValidity == this.uidValidity &&
          other.highestModSeq == this.highestModSeq &&
          other.deltaLink == this.deltaLink &&
          other.lastSyncAt == this.lastSyncAt &&
          other.backfillCursor == this.backfillCursor &&
          other.backfillDone == this.backfillDone);
}

class SyncStatesCompanion extends UpdateCompanion<SyncState> {
  final Value<String> folderId;
  final Value<int?> uidNext;
  final Value<int?> uidValidity;
  final Value<int?> highestModSeq;
  final Value<String?> deltaLink;
  final Value<DateTime?> lastSyncAt;
  final Value<String?> backfillCursor;
  final Value<bool> backfillDone;
  final Value<int> rowid;
  const SyncStatesCompanion({
    this.folderId = const Value.absent(),
    this.uidNext = const Value.absent(),
    this.uidValidity = const Value.absent(),
    this.highestModSeq = const Value.absent(),
    this.deltaLink = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.backfillCursor = const Value.absent(),
    this.backfillDone = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStatesCompanion.insert({
    required String folderId,
    this.uidNext = const Value.absent(),
    this.uidValidity = const Value.absent(),
    this.highestModSeq = const Value.absent(),
    this.deltaLink = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.backfillCursor = const Value.absent(),
    this.backfillDone = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : folderId = Value(folderId);
  static Insertable<SyncState> custom({
    Expression<String>? folderId,
    Expression<int>? uidNext,
    Expression<int>? uidValidity,
    Expression<int>? highestModSeq,
    Expression<String>? deltaLink,
    Expression<DateTime>? lastSyncAt,
    Expression<String>? backfillCursor,
    Expression<bool>? backfillDone,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (folderId != null) 'folder_id': folderId,
      if (uidNext != null) 'uid_next': uidNext,
      if (uidValidity != null) 'uid_validity': uidValidity,
      if (highestModSeq != null) 'highest_mod_seq': highestModSeq,
      if (deltaLink != null) 'delta_link': deltaLink,
      if (lastSyncAt != null) 'last_sync_at': lastSyncAt,
      if (backfillCursor != null) 'backfill_cursor': backfillCursor,
      if (backfillDone != null) 'backfill_done': backfillDone,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStatesCompanion copyWith({
    Value<String>? folderId,
    Value<int?>? uidNext,
    Value<int?>? uidValidity,
    Value<int?>? highestModSeq,
    Value<String?>? deltaLink,
    Value<DateTime?>? lastSyncAt,
    Value<String?>? backfillCursor,
    Value<bool>? backfillDone,
    Value<int>? rowid,
  }) {
    return SyncStatesCompanion(
      folderId: folderId ?? this.folderId,
      uidNext: uidNext ?? this.uidNext,
      uidValidity: uidValidity ?? this.uidValidity,
      highestModSeq: highestModSeq ?? this.highestModSeq,
      deltaLink: deltaLink ?? this.deltaLink,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      backfillCursor: backfillCursor ?? this.backfillCursor,
      backfillDone: backfillDone ?? this.backfillDone,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (uidNext.present) {
      map['uid_next'] = Variable<int>(uidNext.value);
    }
    if (uidValidity.present) {
      map['uid_validity'] = Variable<int>(uidValidity.value);
    }
    if (highestModSeq.present) {
      map['highest_mod_seq'] = Variable<int>(highestModSeq.value);
    }
    if (deltaLink.present) {
      map['delta_link'] = Variable<String>(deltaLink.value);
    }
    if (lastSyncAt.present) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt.value);
    }
    if (backfillCursor.present) {
      map['backfill_cursor'] = Variable<String>(backfillCursor.value);
    }
    if (backfillDone.present) {
      map['backfill_done'] = Variable<bool>(backfillDone.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStatesCompanion(')
          ..write('folderId: $folderId, ')
          ..write('uidNext: $uidNext, ')
          ..write('uidValidity: $uidValidity, ')
          ..write('highestModSeq: $highestModSeq, ')
          ..write('deltaLink: $deltaLink, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('backfillCursor: $backfillCursor, ')
          ..write('backfillDone: $backfillDone, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxOpsTable extends OutboxOps
    with TableInfo<$OutboxOpsTable, OutboxOp> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxOpsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _opTypeMeta = const VerificationMeta('opType');
  @override
  late final GeneratedColumn<String> opType = GeneratedColumn<String>(
    'op_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    opType,
    payload,
    attempts,
    lastError,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_ops';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxOp> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('op_type')) {
      context.handle(
        _opTypeMeta,
        opType.isAcceptableOrUnknown(data['op_type']!, _opTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_opTypeMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxOp map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxOp(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      opType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op_type'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $OutboxOpsTable createAlias(String alias) {
    return $OutboxOpsTable(attachedDatabase, alias);
  }
}

class OutboxOp extends DataClass implements Insertable<OutboxOp> {
  final int id;
  final String accountId;

  /// 操作类型："markRead" / "markUnread" / "flag" / "move" / "delete" / "sendDraft"。
  final String opType;

  /// 操作载荷 JSON（涉及的 messageId 列表、目标 folderId 等）。
  final String payload;

  /// 已尝试次数（用于退避/放弃）。
  final int attempts;
  final String? lastError;
  final DateTime createdAt;
  const OutboxOp({
    required this.id,
    required this.accountId,
    required this.opType,
    required this.payload,
    required this.attempts,
    this.lastError,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['account_id'] = Variable<String>(accountId);
    map['op_type'] = Variable<String>(opType);
    map['payload'] = Variable<String>(payload);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  OutboxOpsCompanion toCompanion(bool nullToAbsent) {
    return OutboxOpsCompanion(
      id: Value(id),
      accountId: Value(accountId),
      opType: Value(opType),
      payload: Value(payload),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
    );
  }

  factory OutboxOp.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxOp(
      id: serializer.fromJson<int>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      opType: serializer.fromJson<String>(json['opType']),
      payload: serializer.fromJson<String>(json['payload']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'accountId': serializer.toJson<String>(accountId),
      'opType': serializer.toJson<String>(opType),
      'payload': serializer.toJson<String>(payload),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OutboxOp copyWith({
    int? id,
    String? accountId,
    String? opType,
    String? payload,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
  }) => OutboxOp(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    opType: opType ?? this.opType,
    payload: payload ?? this.payload,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
  );
  OutboxOp copyWithCompanion(OutboxOpsCompanion data) {
    return OutboxOp(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      opType: data.opType.present ? data.opType.value : this.opType,
      payload: data.payload.present ? data.payload.value : this.payload,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxOp(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('opType: $opType, ')
          ..write('payload: $payload, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    opType,
    payload,
    attempts,
    lastError,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxOp &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.opType == this.opType &&
          other.payload == this.payload &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt);
}

class OutboxOpsCompanion extends UpdateCompanion<OutboxOp> {
  final Value<int> id;
  final Value<String> accountId;
  final Value<String> opType;
  final Value<String> payload;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  const OutboxOpsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.opType = const Value.absent(),
    this.payload = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  OutboxOpsCompanion.insert({
    this.id = const Value.absent(),
    required String accountId,
    required String opType,
    this.payload = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : accountId = Value(accountId),
       opType = Value(opType);
  static Insertable<OutboxOp> custom({
    Expression<int>? id,
    Expression<String>? accountId,
    Expression<String>? opType,
    Expression<String>? payload,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (opType != null) 'op_type': opType,
      if (payload != null) 'payload': payload,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  OutboxOpsCompanion copyWith({
    Value<int>? id,
    Value<String>? accountId,
    Value<String>? opType,
    Value<String>? payload,
    Value<int>? attempts,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
  }) {
    return OutboxOpsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      opType: opType ?? this.opType,
      payload: payload ?? this.payload,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (opType.present) {
      map['op_type'] = Variable<String>(opType.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxOpsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('opType: $opType, ')
          ..write('payload: $payload, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $FoldersTable folders = $FoldersTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $MessageBodiesTable messageBodies = $MessageBodiesTable(this);
  late final $SyncStatesTable syncStates = $SyncStatesTable(this);
  late final $OutboxOpsTable outboxOps = $OutboxOpsTable(this);
  late final AccountDao accountDao = AccountDao(this as AppDatabase);
  late final FolderDao folderDao = FolderDao(this as AppDatabase);
  late final MessageDao messageDao = MessageDao(this as AppDatabase);
  late final OutboxDao outboxDao = OutboxDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    accounts,
    folders,
    messages,
    messageBodies,
    syncStates,
    outboxOps,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('folders', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('messages', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'folders',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('messages', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'messages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('message_bodies', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'folders',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('sync_states', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('outbox_ops', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$AccountsTableCreateCompanionBuilder =
    AccountsCompanion Function({
      required String id,
      required String email,
      required String displayName,
      required AccountType accountType,
      required AuthType authType,
      Value<String?> secretRef,
      Value<String?> imapHost,
      Value<int?> imapPort,
      Value<SocketType?> imapSocketType,
      Value<String?> smtpHost,
      Value<int?> smtpPort,
      Value<SocketType?> smtpSocketType,
      Value<String?> loginName,
      Value<int?> colorValue,
      Value<int> sortIndex,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$AccountsTableUpdateCompanionBuilder =
    AccountsCompanion Function({
      Value<String> id,
      Value<String> email,
      Value<String> displayName,
      Value<AccountType> accountType,
      Value<AuthType> authType,
      Value<String?> secretRef,
      Value<String?> imapHost,
      Value<int?> imapPort,
      Value<SocketType?> imapSocketType,
      Value<String?> smtpHost,
      Value<int?> smtpPort,
      Value<SocketType?> smtpSocketType,
      Value<String?> loginName,
      Value<int?> colorValue,
      Value<int> sortIndex,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$AccountsTableReferences
    extends BaseReferences<_$AppDatabase, $AccountsTable, Account> {
  $$AccountsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FoldersTable, List<Folder>> _foldersRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.folders,
    aliasName: $_aliasNameGenerator(db.accounts.id, db.folders.accountId),
  );

  $$FoldersTableProcessedTableManager get foldersRefs {
    final manager = $$FoldersTableTableManager(
      $_db,
      $_db.folders,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_foldersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MessagesTable, List<Message>> _messagesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.messages,
    aliasName: $_aliasNameGenerator(db.accounts.id, db.messages.accountId),
  );

  $$MessagesTableProcessedTableManager get messagesRefs {
    final manager = $$MessagesTableTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_messagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$OutboxOpsTable, List<OutboxOp>>
  _outboxOpsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.outboxOps,
    aliasName: $_aliasNameGenerator(db.accounts.id, db.outboxOps.accountId),
  );

  $$OutboxOpsTableProcessedTableManager get outboxOpsRefs {
    final manager = $$OutboxOpsTableTableManager(
      $_db,
      $_db.outboxOps,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_outboxOpsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AccountsTableFilterComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AccountType, AccountType, int>
  get accountType => $composableBuilder(
    column: $table.accountType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<AuthType, AuthType, int> get authType =>
      $composableBuilder(
        column: $table.authType,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get secretRef => $composableBuilder(
    column: $table.secretRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imapHost => $composableBuilder(
    column: $table.imapHost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get imapPort => $composableBuilder(
    column: $table.imapPort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SocketType?, SocketType, int>
  get imapSocketType => $composableBuilder(
    column: $table.imapSocketType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get smtpHost => $composableBuilder(
    column: $table.smtpHost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get smtpPort => $composableBuilder(
    column: $table.smtpPort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SocketType?, SocketType, int>
  get smtpSocketType => $composableBuilder(
    column: $table.smtpSocketType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get loginName => $composableBuilder(
    column: $table.loginName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> foldersRefs(
    Expression<bool> Function($$FoldersTableFilterComposer f) f,
  ) {
    final $$FoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableFilterComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> messagesRefs(
    Expression<bool> Function($$MessagesTableFilterComposer f) f,
  ) {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> outboxOpsRefs(
    Expression<bool> Function($$OutboxOpsTableFilterComposer f) f,
  ) {
    final $$OutboxOpsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.outboxOps,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OutboxOpsTableFilterComposer(
            $db: $db,
            $table: $db.outboxOps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get accountType => $composableBuilder(
    column: $table.accountType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get authType => $composableBuilder(
    column: $table.authType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get secretRef => $composableBuilder(
    column: $table.secretRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imapHost => $composableBuilder(
    column: $table.imapHost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get imapPort => $composableBuilder(
    column: $table.imapPort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get imapSocketType => $composableBuilder(
    column: $table.imapSocketType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get smtpHost => $composableBuilder(
    column: $table.smtpHost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get smtpPort => $composableBuilder(
    column: $table.smtpPort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get smtpSocketType => $composableBuilder(
    column: $table.smtpSocketType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loginName => $composableBuilder(
    column: $table.loginName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<AccountType, int> get accountType =>
      $composableBuilder(
        column: $table.accountType,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<AuthType, int> get authType =>
      $composableBuilder(column: $table.authType, builder: (column) => column);

  GeneratedColumn<String> get secretRef =>
      $composableBuilder(column: $table.secretRef, builder: (column) => column);

  GeneratedColumn<String> get imapHost =>
      $composableBuilder(column: $table.imapHost, builder: (column) => column);

  GeneratedColumn<int> get imapPort =>
      $composableBuilder(column: $table.imapPort, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SocketType?, int> get imapSocketType =>
      $composableBuilder(
        column: $table.imapSocketType,
        builder: (column) => column,
      );

  GeneratedColumn<String> get smtpHost =>
      $composableBuilder(column: $table.smtpHost, builder: (column) => column);

  GeneratedColumn<int> get smtpPort =>
      $composableBuilder(column: $table.smtpPort, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SocketType?, int> get smtpSocketType =>
      $composableBuilder(
        column: $table.smtpSocketType,
        builder: (column) => column,
      );

  GeneratedColumn<String> get loginName =>
      $composableBuilder(column: $table.loginName, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> foldersRefs<T extends Object>(
    Expression<T> Function($$FoldersTableAnnotationComposer a) f,
  ) {
    final $$FoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> messagesRefs<T extends Object>(
    Expression<T> Function($$MessagesTableAnnotationComposer a) f,
  ) {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> outboxOpsRefs<T extends Object>(
    Expression<T> Function($$OutboxOpsTableAnnotationComposer a) f,
  ) {
    final $$OutboxOpsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.outboxOps,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OutboxOpsTableAnnotationComposer(
            $db: $db,
            $table: $db.outboxOps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccountsTable,
          Account,
          $$AccountsTableFilterComposer,
          $$AccountsTableOrderingComposer,
          $$AccountsTableAnnotationComposer,
          $$AccountsTableCreateCompanionBuilder,
          $$AccountsTableUpdateCompanionBuilder,
          (Account, $$AccountsTableReferences),
          Account,
          PrefetchHooks Function({
            bool foldersRefs,
            bool messagesRefs,
            bool outboxOpsRefs,
          })
        > {
  $$AccountsTableTableManager(_$AppDatabase db, $AccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<AccountType> accountType = const Value.absent(),
                Value<AuthType> authType = const Value.absent(),
                Value<String?> secretRef = const Value.absent(),
                Value<String?> imapHost = const Value.absent(),
                Value<int?> imapPort = const Value.absent(),
                Value<SocketType?> imapSocketType = const Value.absent(),
                Value<String?> smtpHost = const Value.absent(),
                Value<int?> smtpPort = const Value.absent(),
                Value<SocketType?> smtpSocketType = const Value.absent(),
                Value<String?> loginName = const Value.absent(),
                Value<int?> colorValue = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion(
                id: id,
                email: email,
                displayName: displayName,
                accountType: accountType,
                authType: authType,
                secretRef: secretRef,
                imapHost: imapHost,
                imapPort: imapPort,
                imapSocketType: imapSocketType,
                smtpHost: smtpHost,
                smtpPort: smtpPort,
                smtpSocketType: smtpSocketType,
                loginName: loginName,
                colorValue: colorValue,
                sortIndex: sortIndex,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String email,
                required String displayName,
                required AccountType accountType,
                required AuthType authType,
                Value<String?> secretRef = const Value.absent(),
                Value<String?> imapHost = const Value.absent(),
                Value<int?> imapPort = const Value.absent(),
                Value<SocketType?> imapSocketType = const Value.absent(),
                Value<String?> smtpHost = const Value.absent(),
                Value<int?> smtpPort = const Value.absent(),
                Value<SocketType?> smtpSocketType = const Value.absent(),
                Value<String?> loginName = const Value.absent(),
                Value<int?> colorValue = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion.insert(
                id: id,
                email: email,
                displayName: displayName,
                accountType: accountType,
                authType: authType,
                secretRef: secretRef,
                imapHost: imapHost,
                imapPort: imapPort,
                imapSocketType: imapSocketType,
                smtpHost: smtpHost,
                smtpPort: smtpPort,
                smtpSocketType: smtpSocketType,
                loginName: loginName,
                colorValue: colorValue,
                sortIndex: sortIndex,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AccountsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                foldersRefs = false,
                messagesRefs = false,
                outboxOpsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (foldersRefs) db.folders,
                    if (messagesRefs) db.messages,
                    if (outboxOpsRefs) db.outboxOps,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (foldersRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          Folder
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._foldersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).foldersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (messagesRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          Message
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._messagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).messagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (outboxOpsRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          OutboxOp
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._outboxOpsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).outboxOpsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$AccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccountsTable,
      Account,
      $$AccountsTableFilterComposer,
      $$AccountsTableOrderingComposer,
      $$AccountsTableAnnotationComposer,
      $$AccountsTableCreateCompanionBuilder,
      $$AccountsTableUpdateCompanionBuilder,
      (Account, $$AccountsTableReferences),
      Account,
      PrefetchHooks Function({
        bool foldersRefs,
        bool messagesRefs,
        bool outboxOpsRefs,
      })
    >;
typedef $$FoldersTableCreateCompanionBuilder =
    FoldersCompanion Function({
      required String id,
      required String accountId,
      required String remoteId,
      required String displayName,
      required FolderType folderType,
      Value<String?> parentId,
      Value<int> unreadCount,
      Value<int> totalCount,
      Value<bool> isSubscribed,
      Value<bool> visible,
      Value<bool> syncEnabled,
      Value<bool> notificationsEnabled,
      Value<bool> unified,
      Value<int> sortIndex,
      Value<int> rowid,
    });
typedef $$FoldersTableUpdateCompanionBuilder =
    FoldersCompanion Function({
      Value<String> id,
      Value<String> accountId,
      Value<String> remoteId,
      Value<String> displayName,
      Value<FolderType> folderType,
      Value<String?> parentId,
      Value<int> unreadCount,
      Value<int> totalCount,
      Value<bool> isSubscribed,
      Value<bool> visible,
      Value<bool> syncEnabled,
      Value<bool> notificationsEnabled,
      Value<bool> unified,
      Value<int> sortIndex,
      Value<int> rowid,
    });

final class $$FoldersTableReferences
    extends BaseReferences<_$AppDatabase, $FoldersTable, Folder> {
  $$FoldersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$AppDatabase db) => db.accounts
      .createAlias($_aliasNameGenerator(db.folders.accountId, db.accounts.id));

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$MessagesTable, List<Message>> _messagesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.messages,
    aliasName: $_aliasNameGenerator(db.folders.id, db.messages.folderId),
  );

  $$MessagesTableProcessedTableManager get messagesRefs {
    final manager = $$MessagesTableTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.folderId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_messagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SyncStatesTable, List<SyncState>>
  _syncStatesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.syncStates,
    aliasName: $_aliasNameGenerator(db.folders.id, db.syncStates.folderId),
  );

  $$SyncStatesTableProcessedTableManager get syncStatesRefs {
    final manager = $$SyncStatesTableTableManager(
      $_db,
      $_db.syncStates,
    ).filter((f) => f.folderId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_syncStatesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FoldersTableFilterComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<FolderType, FolderType, int> get folderType =>
      $composableBuilder(
        column: $table.folderType,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalCount => $composableBuilder(
    column: $table.totalCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSubscribed => $composableBuilder(
    column: $table.isSubscribed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get visible => $composableBuilder(
    column: $table.visible,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get syncEnabled => $composableBuilder(
    column: $table.syncEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notificationsEnabled => $composableBuilder(
    column: $table.notificationsEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get unified => $composableBuilder(
    column: $table.unified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> messagesRefs(
    Expression<bool> Function($$MessagesTableFilterComposer f) f,
  ) {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> syncStatesRefs(
    Expression<bool> Function($$SyncStatesTableFilterComposer f) f,
  ) {
    final $$SyncStatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.syncStates,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncStatesTableFilterComposer(
            $db: $db,
            $table: $db.syncStates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get folderType => $composableBuilder(
    column: $table.folderType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalCount => $composableBuilder(
    column: $table.totalCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSubscribed => $composableBuilder(
    column: $table.isSubscribed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get visible => $composableBuilder(
    column: $table.visible,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get syncEnabled => $composableBuilder(
    column: $table.syncEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notificationsEnabled => $composableBuilder(
    column: $table.notificationsEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get unified => $composableBuilder(
    column: $table.unified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<FolderType, int> get folderType =>
      $composableBuilder(
        column: $table.folderType,
        builder: (column) => column,
      );

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalCount => $composableBuilder(
    column: $table.totalCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isSubscribed => $composableBuilder(
    column: $table.isSubscribed,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get visible =>
      $composableBuilder(column: $table.visible, builder: (column) => column);

  GeneratedColumn<bool> get syncEnabled => $composableBuilder(
    column: $table.syncEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get notificationsEnabled => $composableBuilder(
    column: $table.notificationsEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get unified =>
      $composableBuilder(column: $table.unified, builder: (column) => column);

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> messagesRefs<T extends Object>(
    Expression<T> Function($$MessagesTableAnnotationComposer a) f,
  ) {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> syncStatesRefs<T extends Object>(
    Expression<T> Function($$SyncStatesTableAnnotationComposer a) f,
  ) {
    final $$SyncStatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.syncStates,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncStatesTableAnnotationComposer(
            $db: $db,
            $table: $db.syncStates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoldersTable,
          Folder,
          $$FoldersTableFilterComposer,
          $$FoldersTableOrderingComposer,
          $$FoldersTableAnnotationComposer,
          $$FoldersTableCreateCompanionBuilder,
          $$FoldersTableUpdateCompanionBuilder,
          (Folder, $$FoldersTableReferences),
          Folder,
          PrefetchHooks Function({
            bool accountId,
            bool messagesRefs,
            bool syncStatesRefs,
          })
        > {
  $$FoldersTableTableManager(_$AppDatabase db, $FoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> remoteId = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<FolderType> folderType = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<int> unreadCount = const Value.absent(),
                Value<int> totalCount = const Value.absent(),
                Value<bool> isSubscribed = const Value.absent(),
                Value<bool> visible = const Value.absent(),
                Value<bool> syncEnabled = const Value.absent(),
                Value<bool> notificationsEnabled = const Value.absent(),
                Value<bool> unified = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoldersCompanion(
                id: id,
                accountId: accountId,
                remoteId: remoteId,
                displayName: displayName,
                folderType: folderType,
                parentId: parentId,
                unreadCount: unreadCount,
                totalCount: totalCount,
                isSubscribed: isSubscribed,
                visible: visible,
                syncEnabled: syncEnabled,
                notificationsEnabled: notificationsEnabled,
                unified: unified,
                sortIndex: sortIndex,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                required String remoteId,
                required String displayName,
                required FolderType folderType,
                Value<String?> parentId = const Value.absent(),
                Value<int> unreadCount = const Value.absent(),
                Value<int> totalCount = const Value.absent(),
                Value<bool> isSubscribed = const Value.absent(),
                Value<bool> visible = const Value.absent(),
                Value<bool> syncEnabled = const Value.absent(),
                Value<bool> notificationsEnabled = const Value.absent(),
                Value<bool> unified = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoldersCompanion.insert(
                id: id,
                accountId: accountId,
                remoteId: remoteId,
                displayName: displayName,
                folderType: folderType,
                parentId: parentId,
                unreadCount: unreadCount,
                totalCount: totalCount,
                isSubscribed: isSubscribed,
                visible: visible,
                syncEnabled: syncEnabled,
                notificationsEnabled: notificationsEnabled,
                unified: unified,
                sortIndex: sortIndex,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FoldersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                accountId = false,
                messagesRefs = false,
                syncStatesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (messagesRefs) db.messages,
                    if (syncStatesRefs) db.syncStates,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (accountId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.accountId,
                                    referencedTable: $$FoldersTableReferences
                                        ._accountIdTable(db),
                                    referencedColumn: $$FoldersTableReferences
                                        ._accountIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (messagesRefs)
                        await $_getPrefetchedData<
                          Folder,
                          $FoldersTable,
                          Message
                        >(
                          currentTable: table,
                          referencedTable: $$FoldersTableReferences
                              ._messagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FoldersTableReferences(
                                db,
                                table,
                                p0,
                              ).messagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.folderId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (syncStatesRefs)
                        await $_getPrefetchedData<
                          Folder,
                          $FoldersTable,
                          SyncState
                        >(
                          currentTable: table,
                          referencedTable: $$FoldersTableReferences
                              ._syncStatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FoldersTableReferences(
                                db,
                                table,
                                p0,
                              ).syncStatesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.folderId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$FoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoldersTable,
      Folder,
      $$FoldersTableFilterComposer,
      $$FoldersTableOrderingComposer,
      $$FoldersTableAnnotationComposer,
      $$FoldersTableCreateCompanionBuilder,
      $$FoldersTableUpdateCompanionBuilder,
      (Folder, $$FoldersTableReferences),
      Folder,
      PrefetchHooks Function({
        bool accountId,
        bool messagesRefs,
        bool syncStatesRefs,
      })
    >;
typedef $$MessagesTableCreateCompanionBuilder =
    MessagesCompanion Function({
      required String id,
      required String accountId,
      required String folderId,
      Value<int?> imapUid,
      Value<int?> imapUidValidity,
      Value<String?> graphMessageId,
      Value<String?> gmailMessageId,
      Value<String> subject,
      Value<String?> fromName,
      Value<String?> fromEmail,
      Value<String> toRecipients,
      Value<String> ccRecipients,
      required DateTime date,
      Value<String> preview,
      Value<int> flagsBitmask,
      Value<bool> hasAttachments,
      Value<String?> threadKey,
      Value<String?> messageIdHeader,
      Value<String> labels,
      Value<int> rowid,
    });
typedef $$MessagesTableUpdateCompanionBuilder =
    MessagesCompanion Function({
      Value<String> id,
      Value<String> accountId,
      Value<String> folderId,
      Value<int?> imapUid,
      Value<int?> imapUidValidity,
      Value<String?> graphMessageId,
      Value<String?> gmailMessageId,
      Value<String> subject,
      Value<String?> fromName,
      Value<String?> fromEmail,
      Value<String> toRecipients,
      Value<String> ccRecipients,
      Value<DateTime> date,
      Value<String> preview,
      Value<int> flagsBitmask,
      Value<bool> hasAttachments,
      Value<String?> threadKey,
      Value<String?> messageIdHeader,
      Value<String> labels,
      Value<int> rowid,
    });

final class $$MessagesTableReferences
    extends BaseReferences<_$AppDatabase, $MessagesTable, Message> {
  $$MessagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$AppDatabase db) => db.accounts
      .createAlias($_aliasNameGenerator(db.messages.accountId, db.accounts.id));

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $FoldersTable _folderIdTable(_$AppDatabase db) => db.folders
      .createAlias($_aliasNameGenerator(db.messages.folderId, db.folders.id));

  $$FoldersTableProcessedTableManager get folderId {
    final $_column = $_itemColumn<String>('folder_id')!;

    final manager = $$FoldersTableTableManager(
      $_db,
      $_db.folders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_folderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$MessageBodiesTable, List<MessageBody>>
  _messageBodiesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.messageBodies,
    aliasName: $_aliasNameGenerator(db.messages.id, db.messageBodies.messageId),
  );

  $$MessageBodiesTableProcessedTableManager get messageBodiesRefs {
    final manager = $$MessageBodiesTableTableManager(
      $_db,
      $_db.messageBodies,
    ).filter((f) => f.messageId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_messageBodiesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MessagesTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get imapUid => $composableBuilder(
    column: $table.imapUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get imapUidValidity => $composableBuilder(
    column: $table.imapUidValidity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get graphMessageId => $composableBuilder(
    column: $table.graphMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gmailMessageId => $composableBuilder(
    column: $table.gmailMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromName => $composableBuilder(
    column: $table.fromName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromEmail => $composableBuilder(
    column: $table.fromEmail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toRecipients => $composableBuilder(
    column: $table.toRecipients,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ccRecipients => $composableBuilder(
    column: $table.ccRecipients,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preview => $composableBuilder(
    column: $table.preview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get flagsBitmask => $composableBuilder(
    column: $table.flagsBitmask,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasAttachments => $composableBuilder(
    column: $table.hasAttachments,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get threadKey => $composableBuilder(
    column: $table.threadKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageIdHeader => $composableBuilder(
    column: $table.messageIdHeader,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get labels => $composableBuilder(
    column: $table.labels,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FoldersTableFilterComposer get folderId {
    final $$FoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableFilterComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> messageBodiesRefs(
    Expression<bool> Function($$MessageBodiesTableFilterComposer f) f,
  ) {
    final $$MessageBodiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messageBodies,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessageBodiesTableFilterComposer(
            $db: $db,
            $table: $db.messageBodies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get imapUid => $composableBuilder(
    column: $table.imapUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get imapUidValidity => $composableBuilder(
    column: $table.imapUidValidity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get graphMessageId => $composableBuilder(
    column: $table.graphMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gmailMessageId => $composableBuilder(
    column: $table.gmailMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromName => $composableBuilder(
    column: $table.fromName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromEmail => $composableBuilder(
    column: $table.fromEmail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toRecipients => $composableBuilder(
    column: $table.toRecipients,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ccRecipients => $composableBuilder(
    column: $table.ccRecipients,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preview => $composableBuilder(
    column: $table.preview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get flagsBitmask => $composableBuilder(
    column: $table.flagsBitmask,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasAttachments => $composableBuilder(
    column: $table.hasAttachments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get threadKey => $composableBuilder(
    column: $table.threadKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageIdHeader => $composableBuilder(
    column: $table.messageIdHeader,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get labels => $composableBuilder(
    column: $table.labels,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FoldersTableOrderingComposer get folderId {
    final $$FoldersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableOrderingComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get imapUid =>
      $composableBuilder(column: $table.imapUid, builder: (column) => column);

  GeneratedColumn<int> get imapUidValidity => $composableBuilder(
    column: $table.imapUidValidity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get graphMessageId => $composableBuilder(
    column: $table.graphMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get gmailMessageId => $composableBuilder(
    column: $table.gmailMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get fromName =>
      $composableBuilder(column: $table.fromName, builder: (column) => column);

  GeneratedColumn<String> get fromEmail =>
      $composableBuilder(column: $table.fromEmail, builder: (column) => column);

  GeneratedColumn<String> get toRecipients => $composableBuilder(
    column: $table.toRecipients,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ccRecipients => $composableBuilder(
    column: $table.ccRecipients,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get preview =>
      $composableBuilder(column: $table.preview, builder: (column) => column);

  GeneratedColumn<int> get flagsBitmask => $composableBuilder(
    column: $table.flagsBitmask,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasAttachments => $composableBuilder(
    column: $table.hasAttachments,
    builder: (column) => column,
  );

  GeneratedColumn<String> get threadKey =>
      $composableBuilder(column: $table.threadKey, builder: (column) => column);

  GeneratedColumn<String> get messageIdHeader => $composableBuilder(
    column: $table.messageIdHeader,
    builder: (column) => column,
  );

  GeneratedColumn<String> get labels =>
      $composableBuilder(column: $table.labels, builder: (column) => column);

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FoldersTableAnnotationComposer get folderId {
    final $$FoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> messageBodiesRefs<T extends Object>(
    Expression<T> Function($$MessageBodiesTableAnnotationComposer a) f,
  ) {
    final $$MessageBodiesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messageBodies,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessageBodiesTableAnnotationComposer(
            $db: $db,
            $table: $db.messageBodies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessagesTable,
          Message,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (Message, $$MessagesTableReferences),
          Message,
          PrefetchHooks Function({
            bool accountId,
            bool folderId,
            bool messageBodiesRefs,
          })
        > {
  $$MessagesTableTableManager(_$AppDatabase db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> folderId = const Value.absent(),
                Value<int?> imapUid = const Value.absent(),
                Value<int?> imapUidValidity = const Value.absent(),
                Value<String?> graphMessageId = const Value.absent(),
                Value<String?> gmailMessageId = const Value.absent(),
                Value<String> subject = const Value.absent(),
                Value<String?> fromName = const Value.absent(),
                Value<String?> fromEmail = const Value.absent(),
                Value<String> toRecipients = const Value.absent(),
                Value<String> ccRecipients = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> preview = const Value.absent(),
                Value<int> flagsBitmask = const Value.absent(),
                Value<bool> hasAttachments = const Value.absent(),
                Value<String?> threadKey = const Value.absent(),
                Value<String?> messageIdHeader = const Value.absent(),
                Value<String> labels = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                accountId: accountId,
                folderId: folderId,
                imapUid: imapUid,
                imapUidValidity: imapUidValidity,
                graphMessageId: graphMessageId,
                gmailMessageId: gmailMessageId,
                subject: subject,
                fromName: fromName,
                fromEmail: fromEmail,
                toRecipients: toRecipients,
                ccRecipients: ccRecipients,
                date: date,
                preview: preview,
                flagsBitmask: flagsBitmask,
                hasAttachments: hasAttachments,
                threadKey: threadKey,
                messageIdHeader: messageIdHeader,
                labels: labels,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                required String folderId,
                Value<int?> imapUid = const Value.absent(),
                Value<int?> imapUidValidity = const Value.absent(),
                Value<String?> graphMessageId = const Value.absent(),
                Value<String?> gmailMessageId = const Value.absent(),
                Value<String> subject = const Value.absent(),
                Value<String?> fromName = const Value.absent(),
                Value<String?> fromEmail = const Value.absent(),
                Value<String> toRecipients = const Value.absent(),
                Value<String> ccRecipients = const Value.absent(),
                required DateTime date,
                Value<String> preview = const Value.absent(),
                Value<int> flagsBitmask = const Value.absent(),
                Value<bool> hasAttachments = const Value.absent(),
                Value<String?> threadKey = const Value.absent(),
                Value<String?> messageIdHeader = const Value.absent(),
                Value<String> labels = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                accountId: accountId,
                folderId: folderId,
                imapUid: imapUid,
                imapUidValidity: imapUidValidity,
                graphMessageId: graphMessageId,
                gmailMessageId: gmailMessageId,
                subject: subject,
                fromName: fromName,
                fromEmail: fromEmail,
                toRecipients: toRecipients,
                ccRecipients: ccRecipients,
                date: date,
                preview: preview,
                flagsBitmask: flagsBitmask,
                hasAttachments: hasAttachments,
                threadKey: threadKey,
                messageIdHeader: messageIdHeader,
                labels: labels,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MessagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                accountId = false,
                folderId = false,
                messageBodiesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (messageBodiesRefs) db.messageBodies,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (accountId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.accountId,
                                    referencedTable: $$MessagesTableReferences
                                        ._accountIdTable(db),
                                    referencedColumn: $$MessagesTableReferences
                                        ._accountIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (folderId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.folderId,
                                    referencedTable: $$MessagesTableReferences
                                        ._folderIdTable(db),
                                    referencedColumn: $$MessagesTableReferences
                                        ._folderIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (messageBodiesRefs)
                        await $_getPrefetchedData<
                          Message,
                          $MessagesTable,
                          MessageBody
                        >(
                          currentTable: table,
                          referencedTable: $$MessagesTableReferences
                              ._messageBodiesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MessagesTableReferences(
                                db,
                                table,
                                p0,
                              ).messageBodiesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.messageId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessagesTable,
      Message,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (Message, $$MessagesTableReferences),
      Message,
      PrefetchHooks Function({
        bool accountId,
        bool folderId,
        bool messageBodiesRefs,
      })
    >;
typedef $$MessageBodiesTableCreateCompanionBuilder =
    MessageBodiesCompanion Function({
      required String messageId,
      Value<String?> plainText,
      Value<String?> htmlBody,
      Value<BodyFetchState> fetchState,
      Value<String> attachmentsMeta,
      Value<DateTime?> fetchedAt,
      Value<int> rowid,
    });
typedef $$MessageBodiesTableUpdateCompanionBuilder =
    MessageBodiesCompanion Function({
      Value<String> messageId,
      Value<String?> plainText,
      Value<String?> htmlBody,
      Value<BodyFetchState> fetchState,
      Value<String> attachmentsMeta,
      Value<DateTime?> fetchedAt,
      Value<int> rowid,
    });

final class $$MessageBodiesTableReferences
    extends BaseReferences<_$AppDatabase, $MessageBodiesTable, MessageBody> {
  $$MessageBodiesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MessagesTable _messageIdTable(_$AppDatabase db) =>
      db.messages.createAlias(
        $_aliasNameGenerator(db.messageBodies.messageId, db.messages.id),
      );

  $$MessagesTableProcessedTableManager get messageId {
    final $_column = $_itemColumn<String>('message_id')!;

    final manager = $$MessagesTableTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_messageIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MessageBodiesTableFilterComposer
    extends Composer<_$AppDatabase, $MessageBodiesTable> {
  $$MessageBodiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get plainText => $composableBuilder(
    column: $table.plainText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get htmlBody => $composableBuilder(
    column: $table.htmlBody,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<BodyFetchState, BodyFetchState, int>
  get fetchState => $composableBuilder(
    column: $table.fetchState,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get attachmentsMeta => $composableBuilder(
    column: $table.attachmentsMeta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MessagesTableFilterComposer get messageId {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessageBodiesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessageBodiesTable> {
  $$MessageBodiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get plainText => $composableBuilder(
    column: $table.plainText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get htmlBody => $composableBuilder(
    column: $table.htmlBody,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fetchState => $composableBuilder(
    column: $table.fetchState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentsMeta => $composableBuilder(
    column: $table.attachmentsMeta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MessagesTableOrderingComposer get messageId {
    final $$MessagesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableOrderingComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessageBodiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessageBodiesTable> {
  $$MessageBodiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get plainText =>
      $composableBuilder(column: $table.plainText, builder: (column) => column);

  GeneratedColumn<String> get htmlBody =>
      $composableBuilder(column: $table.htmlBody, builder: (column) => column);

  GeneratedColumnWithTypeConverter<BodyFetchState, int> get fetchState =>
      $composableBuilder(
        column: $table.fetchState,
        builder: (column) => column,
      );

  GeneratedColumn<String> get attachmentsMeta => $composableBuilder(
    column: $table.attachmentsMeta,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  $$MessagesTableAnnotationComposer get messageId {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessageBodiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessageBodiesTable,
          MessageBody,
          $$MessageBodiesTableFilterComposer,
          $$MessageBodiesTableOrderingComposer,
          $$MessageBodiesTableAnnotationComposer,
          $$MessageBodiesTableCreateCompanionBuilder,
          $$MessageBodiesTableUpdateCompanionBuilder,
          (MessageBody, $$MessageBodiesTableReferences),
          MessageBody,
          PrefetchHooks Function({bool messageId})
        > {
  $$MessageBodiesTableTableManager(_$AppDatabase db, $MessageBodiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessageBodiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessageBodiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessageBodiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> messageId = const Value.absent(),
                Value<String?> plainText = const Value.absent(),
                Value<String?> htmlBody = const Value.absent(),
                Value<BodyFetchState> fetchState = const Value.absent(),
                Value<String> attachmentsMeta = const Value.absent(),
                Value<DateTime?> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessageBodiesCompanion(
                messageId: messageId,
                plainText: plainText,
                htmlBody: htmlBody,
                fetchState: fetchState,
                attachmentsMeta: attachmentsMeta,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String messageId,
                Value<String?> plainText = const Value.absent(),
                Value<String?> htmlBody = const Value.absent(),
                Value<BodyFetchState> fetchState = const Value.absent(),
                Value<String> attachmentsMeta = const Value.absent(),
                Value<DateTime?> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessageBodiesCompanion.insert(
                messageId: messageId,
                plainText: plainText,
                htmlBody: htmlBody,
                fetchState: fetchState,
                attachmentsMeta: attachmentsMeta,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MessageBodiesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({messageId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (messageId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.messageId,
                                referencedTable: $$MessageBodiesTableReferences
                                    ._messageIdTable(db),
                                referencedColumn: $$MessageBodiesTableReferences
                                    ._messageIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MessageBodiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessageBodiesTable,
      MessageBody,
      $$MessageBodiesTableFilterComposer,
      $$MessageBodiesTableOrderingComposer,
      $$MessageBodiesTableAnnotationComposer,
      $$MessageBodiesTableCreateCompanionBuilder,
      $$MessageBodiesTableUpdateCompanionBuilder,
      (MessageBody, $$MessageBodiesTableReferences),
      MessageBody,
      PrefetchHooks Function({bool messageId})
    >;
typedef $$SyncStatesTableCreateCompanionBuilder =
    SyncStatesCompanion Function({
      required String folderId,
      Value<int?> uidNext,
      Value<int?> uidValidity,
      Value<int?> highestModSeq,
      Value<String?> deltaLink,
      Value<DateTime?> lastSyncAt,
      Value<String?> backfillCursor,
      Value<bool> backfillDone,
      Value<int> rowid,
    });
typedef $$SyncStatesTableUpdateCompanionBuilder =
    SyncStatesCompanion Function({
      Value<String> folderId,
      Value<int?> uidNext,
      Value<int?> uidValidity,
      Value<int?> highestModSeq,
      Value<String?> deltaLink,
      Value<DateTime?> lastSyncAt,
      Value<String?> backfillCursor,
      Value<bool> backfillDone,
      Value<int> rowid,
    });

final class $$SyncStatesTableReferences
    extends BaseReferences<_$AppDatabase, $SyncStatesTable, SyncState> {
  $$SyncStatesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FoldersTable _folderIdTable(_$AppDatabase db) => db.folders
      .createAlias($_aliasNameGenerator(db.syncStates.folderId, db.folders.id));

  $$FoldersTableProcessedTableManager get folderId {
    final $_column = $_itemColumn<String>('folder_id')!;

    final manager = $$FoldersTableTableManager(
      $_db,
      $_db.folders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_folderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SyncStatesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get uidNext => $composableBuilder(
    column: $table.uidNext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get uidValidity => $composableBuilder(
    column: $table.uidValidity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get highestModSeq => $composableBuilder(
    column: $table.highestModSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deltaLink => $composableBuilder(
    column: $table.deltaLink,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backfillCursor => $composableBuilder(
    column: $table.backfillCursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get backfillDone => $composableBuilder(
    column: $table.backfillDone,
    builder: (column) => ColumnFilters(column),
  );

  $$FoldersTableFilterComposer get folderId {
    final $$FoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableFilterComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyncStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get uidNext => $composableBuilder(
    column: $table.uidNext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get uidValidity => $composableBuilder(
    column: $table.uidValidity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get highestModSeq => $composableBuilder(
    column: $table.highestModSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deltaLink => $composableBuilder(
    column: $table.deltaLink,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backfillCursor => $composableBuilder(
    column: $table.backfillCursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get backfillDone => $composableBuilder(
    column: $table.backfillDone,
    builder: (column) => ColumnOrderings(column),
  );

  $$FoldersTableOrderingComposer get folderId {
    final $$FoldersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableOrderingComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyncStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get uidNext =>
      $composableBuilder(column: $table.uidNext, builder: (column) => column);

  GeneratedColumn<int> get uidValidity => $composableBuilder(
    column: $table.uidValidity,
    builder: (column) => column,
  );

  GeneratedColumn<int> get highestModSeq => $composableBuilder(
    column: $table.highestModSeq,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deltaLink =>
      $composableBuilder(column: $table.deltaLink, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get backfillCursor => $composableBuilder(
    column: $table.backfillCursor,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get backfillDone => $composableBuilder(
    column: $table.backfillDone,
    builder: (column) => column,
  );

  $$FoldersTableAnnotationComposer get folderId {
    final $$FoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyncStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStatesTable,
          SyncState,
          $$SyncStatesTableFilterComposer,
          $$SyncStatesTableOrderingComposer,
          $$SyncStatesTableAnnotationComposer,
          $$SyncStatesTableCreateCompanionBuilder,
          $$SyncStatesTableUpdateCompanionBuilder,
          (SyncState, $$SyncStatesTableReferences),
          SyncState,
          PrefetchHooks Function({bool folderId})
        > {
  $$SyncStatesTableTableManager(_$AppDatabase db, $SyncStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> folderId = const Value.absent(),
                Value<int?> uidNext = const Value.absent(),
                Value<int?> uidValidity = const Value.absent(),
                Value<int?> highestModSeq = const Value.absent(),
                Value<String?> deltaLink = const Value.absent(),
                Value<DateTime?> lastSyncAt = const Value.absent(),
                Value<String?> backfillCursor = const Value.absent(),
                Value<bool> backfillDone = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStatesCompanion(
                folderId: folderId,
                uidNext: uidNext,
                uidValidity: uidValidity,
                highestModSeq: highestModSeq,
                deltaLink: deltaLink,
                lastSyncAt: lastSyncAt,
                backfillCursor: backfillCursor,
                backfillDone: backfillDone,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String folderId,
                Value<int?> uidNext = const Value.absent(),
                Value<int?> uidValidity = const Value.absent(),
                Value<int?> highestModSeq = const Value.absent(),
                Value<String?> deltaLink = const Value.absent(),
                Value<DateTime?> lastSyncAt = const Value.absent(),
                Value<String?> backfillCursor = const Value.absent(),
                Value<bool> backfillDone = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStatesCompanion.insert(
                folderId: folderId,
                uidNext: uidNext,
                uidValidity: uidValidity,
                highestModSeq: highestModSeq,
                deltaLink: deltaLink,
                lastSyncAt: lastSyncAt,
                backfillCursor: backfillCursor,
                backfillDone: backfillDone,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SyncStatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({folderId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (folderId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.folderId,
                                referencedTable: $$SyncStatesTableReferences
                                    ._folderIdTable(db),
                                referencedColumn: $$SyncStatesTableReferences
                                    ._folderIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SyncStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStatesTable,
      SyncState,
      $$SyncStatesTableFilterComposer,
      $$SyncStatesTableOrderingComposer,
      $$SyncStatesTableAnnotationComposer,
      $$SyncStatesTableCreateCompanionBuilder,
      $$SyncStatesTableUpdateCompanionBuilder,
      (SyncState, $$SyncStatesTableReferences),
      SyncState,
      PrefetchHooks Function({bool folderId})
    >;
typedef $$OutboxOpsTableCreateCompanionBuilder =
    OutboxOpsCompanion Function({
      Value<int> id,
      required String accountId,
      required String opType,
      Value<String> payload,
      Value<int> attempts,
      Value<String?> lastError,
      Value<DateTime> createdAt,
    });
typedef $$OutboxOpsTableUpdateCompanionBuilder =
    OutboxOpsCompanion Function({
      Value<int> id,
      Value<String> accountId,
      Value<String> opType,
      Value<String> payload,
      Value<int> attempts,
      Value<String?> lastError,
      Value<DateTime> createdAt,
    });

final class $$OutboxOpsTableReferences
    extends BaseReferences<_$AppDatabase, $OutboxOpsTable, OutboxOp> {
  $$OutboxOpsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias(
        $_aliasNameGenerator(db.outboxOps.accountId, db.accounts.id),
      );

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$OutboxOpsTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxOpsTable> {
  $$OutboxOpsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get opType => $composableBuilder(
    column: $table.opType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OutboxOpsTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxOpsTable> {
  $$OutboxOpsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get opType => $composableBuilder(
    column: $table.opType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OutboxOpsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxOpsTable> {
  $$OutboxOpsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get opType =>
      $composableBuilder(column: $table.opType, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OutboxOpsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxOpsTable,
          OutboxOp,
          $$OutboxOpsTableFilterComposer,
          $$OutboxOpsTableOrderingComposer,
          $$OutboxOpsTableAnnotationComposer,
          $$OutboxOpsTableCreateCompanionBuilder,
          $$OutboxOpsTableUpdateCompanionBuilder,
          (OutboxOp, $$OutboxOpsTableReferences),
          OutboxOp,
          PrefetchHooks Function({bool accountId})
        > {
  $$OutboxOpsTableTableManager(_$AppDatabase db, $OutboxOpsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxOpsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxOpsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxOpsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> opType = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => OutboxOpsCompanion(
                id: id,
                accountId: accountId,
                opType: opType,
                payload: payload,
                attempts: attempts,
                lastError: lastError,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String accountId,
                required String opType,
                Value<String> payload = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => OutboxOpsCompanion.insert(
                id: id,
                accountId: accountId,
                opType: opType,
                payload: payload,
                attempts: attempts,
                lastError: lastError,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$OutboxOpsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({accountId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (accountId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.accountId,
                                referencedTable: $$OutboxOpsTableReferences
                                    ._accountIdTable(db),
                                referencedColumn: $$OutboxOpsTableReferences
                                    ._accountIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$OutboxOpsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxOpsTable,
      OutboxOp,
      $$OutboxOpsTableFilterComposer,
      $$OutboxOpsTableOrderingComposer,
      $$OutboxOpsTableAnnotationComposer,
      $$OutboxOpsTableCreateCompanionBuilder,
      $$OutboxOpsTableUpdateCompanionBuilder,
      (OutboxOp, $$OutboxOpsTableReferences),
      OutboxOp,
      PrefetchHooks Function({bool accountId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$FoldersTableTableManager get folders =>
      $$FoldersTableTableManager(_db, _db.folders);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$MessageBodiesTableTableManager get messageBodies =>
      $$MessageBodiesTableTableManager(_db, _db.messageBodies);
  $$SyncStatesTableTableManager get syncStates =>
      $$SyncStatesTableTableManager(_db, _db.syncStates);
  $$OutboxOpsTableTableManager get outboxOps =>
      $$OutboxOpsTableTableManager(_db, _db.outboxOps);
}
