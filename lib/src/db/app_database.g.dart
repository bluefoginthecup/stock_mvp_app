// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ItemsTable extends Items with TableInfo<$ItemsTable, ItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
      'display_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _skuMeta = const VerificationMeta('sku');
  @override
  late final GeneratedColumn<String> sku = GeneratedColumn<String>(
      'sku', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
      'unit', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _searchNormalizedMeta =
      const VerificationMeta('searchNormalized');
  @override
  late final GeneratedColumn<String> searchNormalized = GeneratedColumn<String>(
      'search_normalized', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _searchInitialsMeta =
      const VerificationMeta('searchInitials');
  @override
  late final GeneratedColumn<String> searchInitials = GeneratedColumn<String>(
      'search_initials', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _searchFullNormalizedMeta =
      const VerificationMeta('searchFullNormalized');
  @override
  late final GeneratedColumn<String> searchFullNormalized =
      GeneratedColumn<String>('search_full_normalized', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant(''));
  static const VerificationMeta _folderMeta = const VerificationMeta('folder');
  @override
  late final GeneratedColumn<String> folder = GeneratedColumn<String>(
      'folder', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _subfolderMeta =
      const VerificationMeta('subfolder');
  @override
  late final GeneratedColumn<String> subfolder = GeneratedColumn<String>(
      'subfolder', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _subsubfolderMeta =
      const VerificationMeta('subsubfolder');
  @override
  late final GeneratedColumn<String> subsubfolder = GeneratedColumn<String>(
      'subsubfolder', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _minQtyMeta = const VerificationMeta('minQty');
  @override
  late final GeneratedColumn<int> minQty = GeneratedColumn<int>(
      'min_qty', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _qtyMeta = const VerificationMeta('qty');
  @override
  late final GeneratedColumn<int> qty = GeneratedColumn<int>(
      'qty', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _attrsJsonMeta =
      const VerificationMeta('attrsJson');
  @override
  late final GeneratedColumn<String> attrsJson = GeneratedColumn<String>(
      'attrs_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _unitInMeta = const VerificationMeta('unitIn');
  @override
  late final GeneratedColumn<String> unitIn = GeneratedColumn<String>(
      'unit_in', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('EA'));
  static const VerificationMeta _unitOutMeta =
      const VerificationMeta('unitOut');
  @override
  late final GeneratedColumn<String> unitOut = GeneratedColumn<String>(
      'unit_out', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('EA'));
  static const VerificationMeta _conversionRateMeta =
      const VerificationMeta('conversionRate');
  @override
  late final GeneratedColumn<double> conversionRate = GeneratedColumn<double>(
      'conversion_rate', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(1.0));
  static const VerificationMeta _conversionModeMeta =
      const VerificationMeta('conversionMode');
  @override
  late final GeneratedColumn<String> conversionMode = GeneratedColumn<String>(
      'conversion_mode', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('fixed'));
  static const VerificationMeta _stockHintsJsonMeta =
      const VerificationMeta('stockHintsJson');
  @override
  late final GeneratedColumn<String> stockHintsJson = GeneratedColumn<String>(
      'stock_hints_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _supplierNameMeta =
      const VerificationMeta('supplierName');
  @override
  late final GeneratedColumn<String> supplierName = GeneratedColumn<String>(
      'supplier_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isFavoriteMeta =
      const VerificationMeta('isFavorite');
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
      'is_favorite', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_favorite" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        displayName,
        sku,
        unit,
        searchNormalized,
        searchInitials,
        searchFullNormalized,
        folder,
        subfolder,
        subsubfolder,
        minQty,
        qty,
        kind,
        attrsJson,
        unitIn,
        unitOut,
        conversionRate,
        conversionMode,
        stockHintsJson,
        supplierName,
        isFavorite,
        isDeleted,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'items';
  @override
  VerificationContext validateIntegrity(Insertable<ItemRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
          _displayNameMeta,
          displayName.isAcceptableOrUnknown(
              data['display_name']!, _displayNameMeta));
    }
    if (data.containsKey('sku')) {
      context.handle(
          _skuMeta, sku.isAcceptableOrUnknown(data['sku']!, _skuMeta));
    } else if (isInserting) {
      context.missing(_skuMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
          _unitMeta, unit.isAcceptableOrUnknown(data['unit']!, _unitMeta));
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('search_normalized')) {
      context.handle(
          _searchNormalizedMeta,
          searchNormalized.isAcceptableOrUnknown(
              data['search_normalized']!, _searchNormalizedMeta));
    }
    if (data.containsKey('search_initials')) {
      context.handle(
          _searchInitialsMeta,
          searchInitials.isAcceptableOrUnknown(
              data['search_initials']!, _searchInitialsMeta));
    }
    if (data.containsKey('search_full_normalized')) {
      context.handle(
          _searchFullNormalizedMeta,
          searchFullNormalized.isAcceptableOrUnknown(
              data['search_full_normalized']!, _searchFullNormalizedMeta));
    }
    if (data.containsKey('folder')) {
      context.handle(_folderMeta,
          folder.isAcceptableOrUnknown(data['folder']!, _folderMeta));
    } else if (isInserting) {
      context.missing(_folderMeta);
    }
    if (data.containsKey('subfolder')) {
      context.handle(_subfolderMeta,
          subfolder.isAcceptableOrUnknown(data['subfolder']!, _subfolderMeta));
    }
    if (data.containsKey('subsubfolder')) {
      context.handle(
          _subsubfolderMeta,
          subsubfolder.isAcceptableOrUnknown(
              data['subsubfolder']!, _subsubfolderMeta));
    }
    if (data.containsKey('min_qty')) {
      context.handle(_minQtyMeta,
          minQty.isAcceptableOrUnknown(data['min_qty']!, _minQtyMeta));
    }
    if (data.containsKey('qty')) {
      context.handle(
          _qtyMeta, qty.isAcceptableOrUnknown(data['qty']!, _qtyMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    }
    if (data.containsKey('attrs_json')) {
      context.handle(_attrsJsonMeta,
          attrsJson.isAcceptableOrUnknown(data['attrs_json']!, _attrsJsonMeta));
    }
    if (data.containsKey('unit_in')) {
      context.handle(_unitInMeta,
          unitIn.isAcceptableOrUnknown(data['unit_in']!, _unitInMeta));
    }
    if (data.containsKey('unit_out')) {
      context.handle(_unitOutMeta,
          unitOut.isAcceptableOrUnknown(data['unit_out']!, _unitOutMeta));
    }
    if (data.containsKey('conversion_rate')) {
      context.handle(
          _conversionRateMeta,
          conversionRate.isAcceptableOrUnknown(
              data['conversion_rate']!, _conversionRateMeta));
    }
    if (data.containsKey('conversion_mode')) {
      context.handle(
          _conversionModeMeta,
          conversionMode.isAcceptableOrUnknown(
              data['conversion_mode']!, _conversionModeMeta));
    }
    if (data.containsKey('stock_hints_json')) {
      context.handle(
          _stockHintsJsonMeta,
          stockHintsJson.isAcceptableOrUnknown(
              data['stock_hints_json']!, _stockHintsJsonMeta));
    }
    if (data.containsKey('supplier_name')) {
      context.handle(
          _supplierNameMeta,
          supplierName.isAcceptableOrUnknown(
              data['supplier_name']!, _supplierNameMeta));
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
          _isFavoriteMeta,
          isFavorite.isAcceptableOrUnknown(
              data['is_favorite']!, _isFavoriteMeta));
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name']),
      sku: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sku'])!,
      unit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unit'])!,
      searchNormalized: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}search_normalized'])!,
      searchInitials: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}search_initials'])!,
      searchFullNormalized: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}search_full_normalized'])!,
      folder: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}folder'])!,
      subfolder: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subfolder']),
      subsubfolder: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subsubfolder']),
      minQty: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}min_qty'])!,
      qty: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}qty'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind']),
      attrsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}attrs_json']),
      unitIn: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unit_in'])!,
      unitOut: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unit_out'])!,
      conversionRate: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}conversion_rate'])!,
      conversionMode: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}conversion_mode'])!,
      stockHintsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}stock_hints_json']),
      supplierName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}supplier_name']),
      isFavorite: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_favorite'])!,
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $ItemsTable createAlias(String alias) {
    return $ItemsTable(attachedDatabase, alias);
  }
}

class ItemRow extends DataClass implements Insertable<ItemRow> {
  final String id;
  final String name;
  final String? displayName;
  final String sku;
  final String unit;
  final String searchNormalized;
  final String searchInitials;
  final String searchFullNormalized;
  final String folder;
  final String? subfolder;
  final String? subsubfolder;
  final int minQty;
  final int qty;
  final String? kind;
  final String? attrsJson;
  final String unitIn;
  final String unitOut;
  final double conversionRate;
  final String conversionMode;
  final String? stockHintsJson;
  final String? supplierName;
  final bool isFavorite;
  final bool isDeleted;
  final String? deletedAt;
  const ItemRow(
      {required this.id,
      required this.name,
      this.displayName,
      required this.sku,
      required this.unit,
      required this.searchNormalized,
      required this.searchInitials,
      required this.searchFullNormalized,
      required this.folder,
      this.subfolder,
      this.subsubfolder,
      required this.minQty,
      required this.qty,
      this.kind,
      this.attrsJson,
      required this.unitIn,
      required this.unitOut,
      required this.conversionRate,
      required this.conversionMode,
      this.stockHintsJson,
      this.supplierName,
      required this.isFavorite,
      required this.isDeleted,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    map['sku'] = Variable<String>(sku);
    map['unit'] = Variable<String>(unit);
    map['search_normalized'] = Variable<String>(searchNormalized);
    map['search_initials'] = Variable<String>(searchInitials);
    map['search_full_normalized'] = Variable<String>(searchFullNormalized);
    map['folder'] = Variable<String>(folder);
    if (!nullToAbsent || subfolder != null) {
      map['subfolder'] = Variable<String>(subfolder);
    }
    if (!nullToAbsent || subsubfolder != null) {
      map['subsubfolder'] = Variable<String>(subsubfolder);
    }
    map['min_qty'] = Variable<int>(minQty);
    map['qty'] = Variable<int>(qty);
    if (!nullToAbsent || kind != null) {
      map['kind'] = Variable<String>(kind);
    }
    if (!nullToAbsent || attrsJson != null) {
      map['attrs_json'] = Variable<String>(attrsJson);
    }
    map['unit_in'] = Variable<String>(unitIn);
    map['unit_out'] = Variable<String>(unitOut);
    map['conversion_rate'] = Variable<double>(conversionRate);
    map['conversion_mode'] = Variable<String>(conversionMode);
    if (!nullToAbsent || stockHintsJson != null) {
      map['stock_hints_json'] = Variable<String>(stockHintsJson);
    }
    if (!nullToAbsent || supplierName != null) {
      map['supplier_name'] = Variable<String>(supplierName);
    }
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  ItemsCompanion toCompanion(bool nullToAbsent) {
    return ItemsCompanion(
      id: Value(id),
      name: Value(name),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      sku: Value(sku),
      unit: Value(unit),
      searchNormalized: Value(searchNormalized),
      searchInitials: Value(searchInitials),
      searchFullNormalized: Value(searchFullNormalized),
      folder: Value(folder),
      subfolder: subfolder == null && nullToAbsent
          ? const Value.absent()
          : Value(subfolder),
      subsubfolder: subsubfolder == null && nullToAbsent
          ? const Value.absent()
          : Value(subsubfolder),
      minQty: Value(minQty),
      qty: Value(qty),
      kind: kind == null && nullToAbsent ? const Value.absent() : Value(kind),
      attrsJson: attrsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(attrsJson),
      unitIn: Value(unitIn),
      unitOut: Value(unitOut),
      conversionRate: Value(conversionRate),
      conversionMode: Value(conversionMode),
      stockHintsJson: stockHintsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(stockHintsJson),
      supplierName: supplierName == null && nullToAbsent
          ? const Value.absent()
          : Value(supplierName),
      isFavorite: Value(isFavorite),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory ItemRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      sku: serializer.fromJson<String>(json['sku']),
      unit: serializer.fromJson<String>(json['unit']),
      searchNormalized: serializer.fromJson<String>(json['searchNormalized']),
      searchInitials: serializer.fromJson<String>(json['searchInitials']),
      searchFullNormalized:
          serializer.fromJson<String>(json['searchFullNormalized']),
      folder: serializer.fromJson<String>(json['folder']),
      subfolder: serializer.fromJson<String?>(json['subfolder']),
      subsubfolder: serializer.fromJson<String?>(json['subsubfolder']),
      minQty: serializer.fromJson<int>(json['minQty']),
      qty: serializer.fromJson<int>(json['qty']),
      kind: serializer.fromJson<String?>(json['kind']),
      attrsJson: serializer.fromJson<String?>(json['attrsJson']),
      unitIn: serializer.fromJson<String>(json['unitIn']),
      unitOut: serializer.fromJson<String>(json['unitOut']),
      conversionRate: serializer.fromJson<double>(json['conversionRate']),
      conversionMode: serializer.fromJson<String>(json['conversionMode']),
      stockHintsJson: serializer.fromJson<String?>(json['stockHintsJson']),
      supplierName: serializer.fromJson<String?>(json['supplierName']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'displayName': serializer.toJson<String?>(displayName),
      'sku': serializer.toJson<String>(sku),
      'unit': serializer.toJson<String>(unit),
      'searchNormalized': serializer.toJson<String>(searchNormalized),
      'searchInitials': serializer.toJson<String>(searchInitials),
      'searchFullNormalized': serializer.toJson<String>(searchFullNormalized),
      'folder': serializer.toJson<String>(folder),
      'subfolder': serializer.toJson<String?>(subfolder),
      'subsubfolder': serializer.toJson<String?>(subsubfolder),
      'minQty': serializer.toJson<int>(minQty),
      'qty': serializer.toJson<int>(qty),
      'kind': serializer.toJson<String?>(kind),
      'attrsJson': serializer.toJson<String?>(attrsJson),
      'unitIn': serializer.toJson<String>(unitIn),
      'unitOut': serializer.toJson<String>(unitOut),
      'conversionRate': serializer.toJson<double>(conversionRate),
      'conversionMode': serializer.toJson<String>(conversionMode),
      'stockHintsJson': serializer.toJson<String?>(stockHintsJson),
      'supplierName': serializer.toJson<String?>(supplierName),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  ItemRow copyWith(
          {String? id,
          String? name,
          Value<String?> displayName = const Value.absent(),
          String? sku,
          String? unit,
          String? searchNormalized,
          String? searchInitials,
          String? searchFullNormalized,
          String? folder,
          Value<String?> subfolder = const Value.absent(),
          Value<String?> subsubfolder = const Value.absent(),
          int? minQty,
          int? qty,
          Value<String?> kind = const Value.absent(),
          Value<String?> attrsJson = const Value.absent(),
          String? unitIn,
          String? unitOut,
          double? conversionRate,
          String? conversionMode,
          Value<String?> stockHintsJson = const Value.absent(),
          Value<String?> supplierName = const Value.absent(),
          bool? isFavorite,
          bool? isDeleted,
          Value<String?> deletedAt = const Value.absent()}) =>
      ItemRow(
        id: id ?? this.id,
        name: name ?? this.name,
        displayName: displayName.present ? displayName.value : this.displayName,
        sku: sku ?? this.sku,
        unit: unit ?? this.unit,
        searchNormalized: searchNormalized ?? this.searchNormalized,
        searchInitials: searchInitials ?? this.searchInitials,
        searchFullNormalized: searchFullNormalized ?? this.searchFullNormalized,
        folder: folder ?? this.folder,
        subfolder: subfolder.present ? subfolder.value : this.subfolder,
        subsubfolder:
            subsubfolder.present ? subsubfolder.value : this.subsubfolder,
        minQty: minQty ?? this.minQty,
        qty: qty ?? this.qty,
        kind: kind.present ? kind.value : this.kind,
        attrsJson: attrsJson.present ? attrsJson.value : this.attrsJson,
        unitIn: unitIn ?? this.unitIn,
        unitOut: unitOut ?? this.unitOut,
        conversionRate: conversionRate ?? this.conversionRate,
        conversionMode: conversionMode ?? this.conversionMode,
        stockHintsJson:
            stockHintsJson.present ? stockHintsJson.value : this.stockHintsJson,
        supplierName:
            supplierName.present ? supplierName.value : this.supplierName,
        isFavorite: isFavorite ?? this.isFavorite,
        isDeleted: isDeleted ?? this.isDeleted,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  ItemRow copyWithCompanion(ItemsCompanion data) {
    return ItemRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      sku: data.sku.present ? data.sku.value : this.sku,
      unit: data.unit.present ? data.unit.value : this.unit,
      searchNormalized: data.searchNormalized.present
          ? data.searchNormalized.value
          : this.searchNormalized,
      searchInitials: data.searchInitials.present
          ? data.searchInitials.value
          : this.searchInitials,
      searchFullNormalized: data.searchFullNormalized.present
          ? data.searchFullNormalized.value
          : this.searchFullNormalized,
      folder: data.folder.present ? data.folder.value : this.folder,
      subfolder: data.subfolder.present ? data.subfolder.value : this.subfolder,
      subsubfolder: data.subsubfolder.present
          ? data.subsubfolder.value
          : this.subsubfolder,
      minQty: data.minQty.present ? data.minQty.value : this.minQty,
      qty: data.qty.present ? data.qty.value : this.qty,
      kind: data.kind.present ? data.kind.value : this.kind,
      attrsJson: data.attrsJson.present ? data.attrsJson.value : this.attrsJson,
      unitIn: data.unitIn.present ? data.unitIn.value : this.unitIn,
      unitOut: data.unitOut.present ? data.unitOut.value : this.unitOut,
      conversionRate: data.conversionRate.present
          ? data.conversionRate.value
          : this.conversionRate,
      conversionMode: data.conversionMode.present
          ? data.conversionMode.value
          : this.conversionMode,
      stockHintsJson: data.stockHintsJson.present
          ? data.stockHintsJson.value
          : this.stockHintsJson,
      supplierName: data.supplierName.present
          ? data.supplierName.value
          : this.supplierName,
      isFavorite:
          data.isFavorite.present ? data.isFavorite.value : this.isFavorite,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('displayName: $displayName, ')
          ..write('sku: $sku, ')
          ..write('unit: $unit, ')
          ..write('searchNormalized: $searchNormalized, ')
          ..write('searchInitials: $searchInitials, ')
          ..write('searchFullNormalized: $searchFullNormalized, ')
          ..write('folder: $folder, ')
          ..write('subfolder: $subfolder, ')
          ..write('subsubfolder: $subsubfolder, ')
          ..write('minQty: $minQty, ')
          ..write('qty: $qty, ')
          ..write('kind: $kind, ')
          ..write('attrsJson: $attrsJson, ')
          ..write('unitIn: $unitIn, ')
          ..write('unitOut: $unitOut, ')
          ..write('conversionRate: $conversionRate, ')
          ..write('conversionMode: $conversionMode, ')
          ..write('stockHintsJson: $stockHintsJson, ')
          ..write('supplierName: $supplierName, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        name,
        displayName,
        sku,
        unit,
        searchNormalized,
        searchInitials,
        searchFullNormalized,
        folder,
        subfolder,
        subsubfolder,
        minQty,
        qty,
        kind,
        attrsJson,
        unitIn,
        unitOut,
        conversionRate,
        conversionMode,
        stockHintsJson,
        supplierName,
        isFavorite,
        isDeleted,
        deletedAt
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.displayName == this.displayName &&
          other.sku == this.sku &&
          other.unit == this.unit &&
          other.searchNormalized == this.searchNormalized &&
          other.searchInitials == this.searchInitials &&
          other.searchFullNormalized == this.searchFullNormalized &&
          other.folder == this.folder &&
          other.subfolder == this.subfolder &&
          other.subsubfolder == this.subsubfolder &&
          other.minQty == this.minQty &&
          other.qty == this.qty &&
          other.kind == this.kind &&
          other.attrsJson == this.attrsJson &&
          other.unitIn == this.unitIn &&
          other.unitOut == this.unitOut &&
          other.conversionRate == this.conversionRate &&
          other.conversionMode == this.conversionMode &&
          other.stockHintsJson == this.stockHintsJson &&
          other.supplierName == this.supplierName &&
          other.isFavorite == this.isFavorite &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt);
}

class ItemsCompanion extends UpdateCompanion<ItemRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> displayName;
  final Value<String> sku;
  final Value<String> unit;
  final Value<String> searchNormalized;
  final Value<String> searchInitials;
  final Value<String> searchFullNormalized;
  final Value<String> folder;
  final Value<String?> subfolder;
  final Value<String?> subsubfolder;
  final Value<int> minQty;
  final Value<int> qty;
  final Value<String?> kind;
  final Value<String?> attrsJson;
  final Value<String> unitIn;
  final Value<String> unitOut;
  final Value<double> conversionRate;
  final Value<String> conversionMode;
  final Value<String?> stockHintsJson;
  final Value<String?> supplierName;
  final Value<bool> isFavorite;
  final Value<bool> isDeleted;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const ItemsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.displayName = const Value.absent(),
    this.sku = const Value.absent(),
    this.unit = const Value.absent(),
    this.searchNormalized = const Value.absent(),
    this.searchInitials = const Value.absent(),
    this.searchFullNormalized = const Value.absent(),
    this.folder = const Value.absent(),
    this.subfolder = const Value.absent(),
    this.subsubfolder = const Value.absent(),
    this.minQty = const Value.absent(),
    this.qty = const Value.absent(),
    this.kind = const Value.absent(),
    this.attrsJson = const Value.absent(),
    this.unitIn = const Value.absent(),
    this.unitOut = const Value.absent(),
    this.conversionRate = const Value.absent(),
    this.conversionMode = const Value.absent(),
    this.stockHintsJson = const Value.absent(),
    this.supplierName = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemsCompanion.insert({
    required String id,
    required String name,
    this.displayName = const Value.absent(),
    required String sku,
    required String unit,
    this.searchNormalized = const Value.absent(),
    this.searchInitials = const Value.absent(),
    this.searchFullNormalized = const Value.absent(),
    required String folder,
    this.subfolder = const Value.absent(),
    this.subsubfolder = const Value.absent(),
    this.minQty = const Value.absent(),
    this.qty = const Value.absent(),
    this.kind = const Value.absent(),
    this.attrsJson = const Value.absent(),
    this.unitIn = const Value.absent(),
    this.unitOut = const Value.absent(),
    this.conversionRate = const Value.absent(),
    this.conversionMode = const Value.absent(),
    this.stockHintsJson = const Value.absent(),
    this.supplierName = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        sku = Value(sku),
        unit = Value(unit),
        folder = Value(folder);
  static Insertable<ItemRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? displayName,
    Expression<String>? sku,
    Expression<String>? unit,
    Expression<String>? searchNormalized,
    Expression<String>? searchInitials,
    Expression<String>? searchFullNormalized,
    Expression<String>? folder,
    Expression<String>? subfolder,
    Expression<String>? subsubfolder,
    Expression<int>? minQty,
    Expression<int>? qty,
    Expression<String>? kind,
    Expression<String>? attrsJson,
    Expression<String>? unitIn,
    Expression<String>? unitOut,
    Expression<double>? conversionRate,
    Expression<String>? conversionMode,
    Expression<String>? stockHintsJson,
    Expression<String>? supplierName,
    Expression<bool>? isFavorite,
    Expression<bool>? isDeleted,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (displayName != null) 'display_name': displayName,
      if (sku != null) 'sku': sku,
      if (unit != null) 'unit': unit,
      if (searchNormalized != null) 'search_normalized': searchNormalized,
      if (searchInitials != null) 'search_initials': searchInitials,
      if (searchFullNormalized != null)
        'search_full_normalized': searchFullNormalized,
      if (folder != null) 'folder': folder,
      if (subfolder != null) 'subfolder': subfolder,
      if (subsubfolder != null) 'subsubfolder': subsubfolder,
      if (minQty != null) 'min_qty': minQty,
      if (qty != null) 'qty': qty,
      if (kind != null) 'kind': kind,
      if (attrsJson != null) 'attrs_json': attrsJson,
      if (unitIn != null) 'unit_in': unitIn,
      if (unitOut != null) 'unit_out': unitOut,
      if (conversionRate != null) 'conversion_rate': conversionRate,
      if (conversionMode != null) 'conversion_mode': conversionMode,
      if (stockHintsJson != null) 'stock_hints_json': stockHintsJson,
      if (supplierName != null) 'supplier_name': supplierName,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String?>? displayName,
      Value<String>? sku,
      Value<String>? unit,
      Value<String>? searchNormalized,
      Value<String>? searchInitials,
      Value<String>? searchFullNormalized,
      Value<String>? folder,
      Value<String?>? subfolder,
      Value<String?>? subsubfolder,
      Value<int>? minQty,
      Value<int>? qty,
      Value<String?>? kind,
      Value<String?>? attrsJson,
      Value<String>? unitIn,
      Value<String>? unitOut,
      Value<double>? conversionRate,
      Value<String>? conversionMode,
      Value<String?>? stockHintsJson,
      Value<String?>? supplierName,
      Value<bool>? isFavorite,
      Value<bool>? isDeleted,
      Value<String?>? deletedAt,
      Value<int>? rowid}) {
    return ItemsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      sku: sku ?? this.sku,
      unit: unit ?? this.unit,
      searchNormalized: searchNormalized ?? this.searchNormalized,
      searchInitials: searchInitials ?? this.searchInitials,
      searchFullNormalized: searchFullNormalized ?? this.searchFullNormalized,
      folder: folder ?? this.folder,
      subfolder: subfolder ?? this.subfolder,
      subsubfolder: subsubfolder ?? this.subsubfolder,
      minQty: minQty ?? this.minQty,
      qty: qty ?? this.qty,
      kind: kind ?? this.kind,
      attrsJson: attrsJson ?? this.attrsJson,
      unitIn: unitIn ?? this.unitIn,
      unitOut: unitOut ?? this.unitOut,
      conversionRate: conversionRate ?? this.conversionRate,
      conversionMode: conversionMode ?? this.conversionMode,
      stockHintsJson: stockHintsJson ?? this.stockHintsJson,
      supplierName: supplierName ?? this.supplierName,
      isFavorite: isFavorite ?? this.isFavorite,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (sku.present) {
      map['sku'] = Variable<String>(sku.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (searchNormalized.present) {
      map['search_normalized'] = Variable<String>(searchNormalized.value);
    }
    if (searchInitials.present) {
      map['search_initials'] = Variable<String>(searchInitials.value);
    }
    if (searchFullNormalized.present) {
      map['search_full_normalized'] =
          Variable<String>(searchFullNormalized.value);
    }
    if (folder.present) {
      map['folder'] = Variable<String>(folder.value);
    }
    if (subfolder.present) {
      map['subfolder'] = Variable<String>(subfolder.value);
    }
    if (subsubfolder.present) {
      map['subsubfolder'] = Variable<String>(subsubfolder.value);
    }
    if (minQty.present) {
      map['min_qty'] = Variable<int>(minQty.value);
    }
    if (qty.present) {
      map['qty'] = Variable<int>(qty.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (attrsJson.present) {
      map['attrs_json'] = Variable<String>(attrsJson.value);
    }
    if (unitIn.present) {
      map['unit_in'] = Variable<String>(unitIn.value);
    }
    if (unitOut.present) {
      map['unit_out'] = Variable<String>(unitOut.value);
    }
    if (conversionRate.present) {
      map['conversion_rate'] = Variable<double>(conversionRate.value);
    }
    if (conversionMode.present) {
      map['conversion_mode'] = Variable<String>(conversionMode.value);
    }
    if (stockHintsJson.present) {
      map['stock_hints_json'] = Variable<String>(stockHintsJson.value);
    }
    if (supplierName.present) {
      map['supplier_name'] = Variable<String>(supplierName.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('displayName: $displayName, ')
          ..write('sku: $sku, ')
          ..write('unit: $unit, ')
          ..write('searchNormalized: $searchNormalized, ')
          ..write('searchInitials: $searchInitials, ')
          ..write('searchFullNormalized: $searchFullNormalized, ')
          ..write('folder: $folder, ')
          ..write('subfolder: $subfolder, ')
          ..write('subsubfolder: $subsubfolder, ')
          ..write('minQty: $minQty, ')
          ..write('qty: $qty, ')
          ..write('kind: $kind, ')
          ..write('attrsJson: $attrsJson, ')
          ..write('unitIn: $unitIn, ')
          ..write('unitOut: $unitOut, ')
          ..write('conversionRate: $conversionRate, ')
          ..write('conversionMode: $conversionMode, ')
          ..write('stockHintsJson: $stockHintsJson, ')
          ..write('supplierName: $supplierName, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FoldersTable extends Folders with TableInfo<$FoldersTable, FolderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _parentIdMeta =
      const VerificationMeta('parentId');
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
      'parent_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES folders (id) ON DELETE SET NULL'));
  static const VerificationMeta _depthMeta = const VerificationMeta('depth');
  @override
  late final GeneratedColumn<int> depth = GeneratedColumn<int>(
      'depth', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _orderMeta = const VerificationMeta('order');
  @override
  late final GeneratedColumn<int> order = GeneratedColumn<int>(
      'order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _searchNormalizedMeta =
      const VerificationMeta('searchNormalized');
  @override
  late final GeneratedColumn<String> searchNormalized = GeneratedColumn<String>(
      'search_normalized', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _searchInitialsMeta =
      const VerificationMeta('searchInitials');
  @override
  late final GeneratedColumn<String> searchInitials = GeneratedColumn<String>(
      'search_initials', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, parentId, depth, order, searchNormalized, searchInitials];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'folders';
  @override
  VerificationContext validateIntegrity(Insertable<FolderRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(_parentIdMeta,
          parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta));
    }
    if (data.containsKey('depth')) {
      context.handle(
          _depthMeta, depth.isAcceptableOrUnknown(data['depth']!, _depthMeta));
    } else if (isInserting) {
      context.missing(_depthMeta);
    }
    if (data.containsKey('order')) {
      context.handle(
          _orderMeta, order.isAcceptableOrUnknown(data['order']!, _orderMeta));
    }
    if (data.containsKey('search_normalized')) {
      context.handle(
          _searchNormalizedMeta,
          searchNormalized.isAcceptableOrUnknown(
              data['search_normalized']!, _searchNormalizedMeta));
    }
    if (data.containsKey('search_initials')) {
      context.handle(
          _searchInitialsMeta,
          searchInitials.isAcceptableOrUnknown(
              data['search_initials']!, _searchInitialsMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FolderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FolderRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      parentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parent_id']),
      depth: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}depth'])!,
      order: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}order'])!,
      searchNormalized: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}search_normalized'])!,
      searchInitials: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}search_initials'])!,
    );
  }

  @override
  $FoldersTable createAlias(String alias) {
    return $FoldersTable(attachedDatabase, alias);
  }
}

class FolderRow extends DataClass implements Insertable<FolderRow> {
  final String id;
  final String name;
  final String? parentId;
  final int depth;
  final int order;
  final String searchNormalized;
  final String searchInitials;
  const FolderRow(
      {required this.id,
      required this.name,
      this.parentId,
      required this.depth,
      required this.order,
      required this.searchNormalized,
      required this.searchInitials});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['depth'] = Variable<int>(depth);
    map['order'] = Variable<int>(order);
    map['search_normalized'] = Variable<String>(searchNormalized);
    map['search_initials'] = Variable<String>(searchInitials);
    return map;
  }

  FoldersCompanion toCompanion(bool nullToAbsent) {
    return FoldersCompanion(
      id: Value(id),
      name: Value(name),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      depth: Value(depth),
      order: Value(order),
      searchNormalized: Value(searchNormalized),
      searchInitials: Value(searchInitials),
    );
  }

  factory FolderRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FolderRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      depth: serializer.fromJson<int>(json['depth']),
      order: serializer.fromJson<int>(json['order']),
      searchNormalized: serializer.fromJson<String>(json['searchNormalized']),
      searchInitials: serializer.fromJson<String>(json['searchInitials']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'parentId': serializer.toJson<String?>(parentId),
      'depth': serializer.toJson<int>(depth),
      'order': serializer.toJson<int>(order),
      'searchNormalized': serializer.toJson<String>(searchNormalized),
      'searchInitials': serializer.toJson<String>(searchInitials),
    };
  }

  FolderRow copyWith(
          {String? id,
          String? name,
          Value<String?> parentId = const Value.absent(),
          int? depth,
          int? order,
          String? searchNormalized,
          String? searchInitials}) =>
      FolderRow(
        id: id ?? this.id,
        name: name ?? this.name,
        parentId: parentId.present ? parentId.value : this.parentId,
        depth: depth ?? this.depth,
        order: order ?? this.order,
        searchNormalized: searchNormalized ?? this.searchNormalized,
        searchInitials: searchInitials ?? this.searchInitials,
      );
  FolderRow copyWithCompanion(FoldersCompanion data) {
    return FolderRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      depth: data.depth.present ? data.depth.value : this.depth,
      order: data.order.present ? data.order.value : this.order,
      searchNormalized: data.searchNormalized.present
          ? data.searchNormalized.value
          : this.searchNormalized,
      searchInitials: data.searchInitials.present
          ? data.searchInitials.value
          : this.searchInitials,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FolderRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId, ')
          ..write('depth: $depth, ')
          ..write('order: $order, ')
          ..write('searchNormalized: $searchNormalized, ')
          ..write('searchInitials: $searchInitials')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, name, parentId, depth, order, searchNormalized, searchInitials);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FolderRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.parentId == this.parentId &&
          other.depth == this.depth &&
          other.order == this.order &&
          other.searchNormalized == this.searchNormalized &&
          other.searchInitials == this.searchInitials);
}

class FoldersCompanion extends UpdateCompanion<FolderRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> parentId;
  final Value<int> depth;
  final Value<int> order;
  final Value<String> searchNormalized;
  final Value<String> searchInitials;
  final Value<int> rowid;
  const FoldersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.parentId = const Value.absent(),
    this.depth = const Value.absent(),
    this.order = const Value.absent(),
    this.searchNormalized = const Value.absent(),
    this.searchInitials = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FoldersCompanion.insert({
    required String id,
    required String name,
    this.parentId = const Value.absent(),
    required int depth,
    this.order = const Value.absent(),
    this.searchNormalized = const Value.absent(),
    this.searchInitials = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        depth = Value(depth);
  static Insertable<FolderRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? parentId,
    Expression<int>? depth,
    Expression<int>? order,
    Expression<String>? searchNormalized,
    Expression<String>? searchInitials,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (parentId != null) 'parent_id': parentId,
      if (depth != null) 'depth': depth,
      if (order != null) 'order': order,
      if (searchNormalized != null) 'search_normalized': searchNormalized,
      if (searchInitials != null) 'search_initials': searchInitials,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FoldersCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String?>? parentId,
      Value<int>? depth,
      Value<int>? order,
      Value<String>? searchNormalized,
      Value<String>? searchInitials,
      Value<int>? rowid}) {
    return FoldersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      depth: depth ?? this.depth,
      order: order ?? this.order,
      searchNormalized: searchNormalized ?? this.searchNormalized,
      searchInitials: searchInitials ?? this.searchInitials,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (depth.present) {
      map['depth'] = Variable<int>(depth.value);
    }
    if (order.present) {
      map['order'] = Variable<int>(order.value);
    }
    if (searchNormalized.present) {
      map['search_normalized'] = Variable<String>(searchNormalized.value);
    }
    if (searchInitials.present) {
      map['search_initials'] = Variable<String>(searchInitials.value);
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
          ..write('name: $name, ')
          ..write('parentId: $parentId, ')
          ..write('depth: $depth, ')
          ..write('order: $order, ')
          ..write('searchNormalized: $searchNormalized, ')
          ..write('searchInitials: $searchInitials, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ItemPathsTable extends ItemPaths
    with TableInfo<$ItemPathsTable, ItemPathRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemPathsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
      'item_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES items (id) ON DELETE CASCADE'));
  static const VerificationMeta _l1IdMeta = const VerificationMeta('l1Id');
  @override
  late final GeneratedColumn<String> l1Id = GeneratedColumn<String>(
      'l1_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES folders (id) ON DELETE SET NULL'));
  static const VerificationMeta _l2IdMeta = const VerificationMeta('l2Id');
  @override
  late final GeneratedColumn<String> l2Id = GeneratedColumn<String>(
      'l2_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES folders (id) ON DELETE SET NULL'));
  static const VerificationMeta _l3IdMeta = const VerificationMeta('l3Id');
  @override
  late final GeneratedColumn<String> l3Id = GeneratedColumn<String>(
      'l3_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES folders (id) ON DELETE SET NULL'));
  @override
  List<GeneratedColumn> get $columns => [itemId, l1Id, l2Id, l3Id];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'item_paths';
  @override
  VerificationContext validateIntegrity(Insertable<ItemPathRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('l1_id')) {
      context.handle(
          _l1IdMeta, l1Id.isAcceptableOrUnknown(data['l1_id']!, _l1IdMeta));
    }
    if (data.containsKey('l2_id')) {
      context.handle(
          _l2IdMeta, l2Id.isAcceptableOrUnknown(data['l2_id']!, _l2IdMeta));
    }
    if (data.containsKey('l3_id')) {
      context.handle(
          _l3IdMeta, l3Id.isAcceptableOrUnknown(data['l3_id']!, _l3IdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId};
  @override
  ItemPathRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemPathRow(
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      l1Id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}l1_id']),
      l2Id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}l2_id']),
      l3Id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}l3_id']),
    );
  }

  @override
  $ItemPathsTable createAlias(String alias) {
    return $ItemPathsTable(attachedDatabase, alias);
  }
}

class ItemPathRow extends DataClass implements Insertable<ItemPathRow> {
  final String itemId;
  final String? l1Id;
  final String? l2Id;
  final String? l3Id;
  const ItemPathRow({required this.itemId, this.l1Id, this.l2Id, this.l3Id});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<String>(itemId);
    if (!nullToAbsent || l1Id != null) {
      map['l1_id'] = Variable<String>(l1Id);
    }
    if (!nullToAbsent || l2Id != null) {
      map['l2_id'] = Variable<String>(l2Id);
    }
    if (!nullToAbsent || l3Id != null) {
      map['l3_id'] = Variable<String>(l3Id);
    }
    return map;
  }

  ItemPathsCompanion toCompanion(bool nullToAbsent) {
    return ItemPathsCompanion(
      itemId: Value(itemId),
      l1Id: l1Id == null && nullToAbsent ? const Value.absent() : Value(l1Id),
      l2Id: l2Id == null && nullToAbsent ? const Value.absent() : Value(l2Id),
      l3Id: l3Id == null && nullToAbsent ? const Value.absent() : Value(l3Id),
    );
  }

  factory ItemPathRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemPathRow(
      itemId: serializer.fromJson<String>(json['itemId']),
      l1Id: serializer.fromJson<String?>(json['l1Id']),
      l2Id: serializer.fromJson<String?>(json['l2Id']),
      l3Id: serializer.fromJson<String?>(json['l3Id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemId': serializer.toJson<String>(itemId),
      'l1Id': serializer.toJson<String?>(l1Id),
      'l2Id': serializer.toJson<String?>(l2Id),
      'l3Id': serializer.toJson<String?>(l3Id),
    };
  }

  ItemPathRow copyWith(
          {String? itemId,
          Value<String?> l1Id = const Value.absent(),
          Value<String?> l2Id = const Value.absent(),
          Value<String?> l3Id = const Value.absent()}) =>
      ItemPathRow(
        itemId: itemId ?? this.itemId,
        l1Id: l1Id.present ? l1Id.value : this.l1Id,
        l2Id: l2Id.present ? l2Id.value : this.l2Id,
        l3Id: l3Id.present ? l3Id.value : this.l3Id,
      );
  ItemPathRow copyWithCompanion(ItemPathsCompanion data) {
    return ItemPathRow(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      l1Id: data.l1Id.present ? data.l1Id.value : this.l1Id,
      l2Id: data.l2Id.present ? data.l2Id.value : this.l2Id,
      l3Id: data.l3Id.present ? data.l3Id.value : this.l3Id,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemPathRow(')
          ..write('itemId: $itemId, ')
          ..write('l1Id: $l1Id, ')
          ..write('l2Id: $l2Id, ')
          ..write('l3Id: $l3Id')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(itemId, l1Id, l2Id, l3Id);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemPathRow &&
          other.itemId == this.itemId &&
          other.l1Id == this.l1Id &&
          other.l2Id == this.l2Id &&
          other.l3Id == this.l3Id);
}

class ItemPathsCompanion extends UpdateCompanion<ItemPathRow> {
  final Value<String> itemId;
  final Value<String?> l1Id;
  final Value<String?> l2Id;
  final Value<String?> l3Id;
  final Value<int> rowid;
  const ItemPathsCompanion({
    this.itemId = const Value.absent(),
    this.l1Id = const Value.absent(),
    this.l2Id = const Value.absent(),
    this.l3Id = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemPathsCompanion.insert({
    required String itemId,
    this.l1Id = const Value.absent(),
    this.l2Id = const Value.absent(),
    this.l3Id = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId);
  static Insertable<ItemPathRow> custom({
    Expression<String>? itemId,
    Expression<String>? l1Id,
    Expression<String>? l2Id,
    Expression<String>? l3Id,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (l1Id != null) 'l1_id': l1Id,
      if (l2Id != null) 'l2_id': l2Id,
      if (l3Id != null) 'l3_id': l3Id,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemPathsCompanion copyWith(
      {Value<String>? itemId,
      Value<String?>? l1Id,
      Value<String?>? l2Id,
      Value<String?>? l3Id,
      Value<int>? rowid}) {
    return ItemPathsCompanion(
      itemId: itemId ?? this.itemId,
      l1Id: l1Id ?? this.l1Id,
      l2Id: l2Id ?? this.l2Id,
      l3Id: l3Id ?? this.l3Id,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (l1Id.present) {
      map['l1_id'] = Variable<String>(l1Id.value);
    }
    if (l2Id.present) {
      map['l2_id'] = Variable<String>(l2Id.value);
    }
    if (l3Id.present) {
      map['l3_id'] = Variable<String>(l3Id.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemPathsCompanion(')
          ..write('itemId: $itemId, ')
          ..write('l1Id: $l1Id, ')
          ..write('l2Id: $l2Id, ')
          ..write('l3Id: $l3Id, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TxnsTable extends Txns with TableInfo<$TxnsTable, TxnRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TxnsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tsMeta = const VerificationMeta('ts');
  @override
  late final GeneratedColumn<String> ts = GeneratedColumn<String>(
      'ts', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
      'item_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES items (id) ON DELETE CASCADE'));
  static const VerificationMeta _qtyMeta = const VerificationMeta('qty');
  @override
  late final GeneratedColumn<int> qty = GeneratedColumn<int>(
      'qty', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _refTypeMeta =
      const VerificationMeta('refType');
  @override
  late final GeneratedColumn<String> refType = GeneratedColumn<String>(
      'ref_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _refIdMeta = const VerificationMeta('refId');
  @override
  late final GeneratedColumn<String> refId = GeneratedColumn<String>(
      'ref_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _memoMeta = const VerificationMeta('memo');
  @override
  late final GeneratedColumn<String> memo = GeneratedColumn<String>(
      'memo', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceKeyMeta =
      const VerificationMeta('sourceKey');
  @override
  late final GeneratedColumn<String> sourceKey = GeneratedColumn<String>(
      'source_key', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        ts,
        type,
        status,
        itemId,
        qty,
        refType,
        refId,
        note,
        memo,
        sourceKey,
        isDeleted,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'txns';
  @override
  VerificationContext validateIntegrity(Insertable<TxnRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('ts')) {
      context.handle(_tsMeta, ts.isAcceptableOrUnknown(data['ts']!, _tsMeta));
    } else if (isInserting) {
      context.missing(_tsMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('qty')) {
      context.handle(
          _qtyMeta, qty.isAcceptableOrUnknown(data['qty']!, _qtyMeta));
    } else if (isInserting) {
      context.missing(_qtyMeta);
    }
    if (data.containsKey('ref_type')) {
      context.handle(_refTypeMeta,
          refType.isAcceptableOrUnknown(data['ref_type']!, _refTypeMeta));
    } else if (isInserting) {
      context.missing(_refTypeMeta);
    }
    if (data.containsKey('ref_id')) {
      context.handle(
          _refIdMeta, refId.isAcceptableOrUnknown(data['ref_id']!, _refIdMeta));
    } else if (isInserting) {
      context.missing(_refIdMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('memo')) {
      context.handle(
          _memoMeta, memo.isAcceptableOrUnknown(data['memo']!, _memoMeta));
    }
    if (data.containsKey('source_key')) {
      context.handle(_sourceKeyMeta,
          sourceKey.isAcceptableOrUnknown(data['source_key']!, _sourceKeyMeta));
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TxnRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TxnRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      ts: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ts'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      qty: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}qty'])!,
      refType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ref_type'])!,
      refId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ref_id'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      memo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}memo']),
      sourceKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_key']),
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $TxnsTable createAlias(String alias) {
    return $TxnsTable(attachedDatabase, alias);
  }
}

class TxnRow extends DataClass implements Insertable<TxnRow> {
  final String id;
  final String ts;
  final String type;
  final String status;
  final String itemId;
  final int qty;
  final String refType;
  final String refId;
  final String? note;
  final String? memo;
  final String? sourceKey;
  final bool isDeleted;
  final String? deletedAt;
  const TxnRow(
      {required this.id,
      required this.ts,
      required this.type,
      required this.status,
      required this.itemId,
      required this.qty,
      required this.refType,
      required this.refId,
      this.note,
      this.memo,
      this.sourceKey,
      required this.isDeleted,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['ts'] = Variable<String>(ts);
    map['type'] = Variable<String>(type);
    map['status'] = Variable<String>(status);
    map['item_id'] = Variable<String>(itemId);
    map['qty'] = Variable<int>(qty);
    map['ref_type'] = Variable<String>(refType);
    map['ref_id'] = Variable<String>(refId);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || memo != null) {
      map['memo'] = Variable<String>(memo);
    }
    if (!nullToAbsent || sourceKey != null) {
      map['source_key'] = Variable<String>(sourceKey);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  TxnsCompanion toCompanion(bool nullToAbsent) {
    return TxnsCompanion(
      id: Value(id),
      ts: Value(ts),
      type: Value(type),
      status: Value(status),
      itemId: Value(itemId),
      qty: Value(qty),
      refType: Value(refType),
      refId: Value(refId),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      memo: memo == null && nullToAbsent ? const Value.absent() : Value(memo),
      sourceKey: sourceKey == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceKey),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory TxnRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TxnRow(
      id: serializer.fromJson<String>(json['id']),
      ts: serializer.fromJson<String>(json['ts']),
      type: serializer.fromJson<String>(json['type']),
      status: serializer.fromJson<String>(json['status']),
      itemId: serializer.fromJson<String>(json['itemId']),
      qty: serializer.fromJson<int>(json['qty']),
      refType: serializer.fromJson<String>(json['refType']),
      refId: serializer.fromJson<String>(json['refId']),
      note: serializer.fromJson<String?>(json['note']),
      memo: serializer.fromJson<String?>(json['memo']),
      sourceKey: serializer.fromJson<String?>(json['sourceKey']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ts': serializer.toJson<String>(ts),
      'type': serializer.toJson<String>(type),
      'status': serializer.toJson<String>(status),
      'itemId': serializer.toJson<String>(itemId),
      'qty': serializer.toJson<int>(qty),
      'refType': serializer.toJson<String>(refType),
      'refId': serializer.toJson<String>(refId),
      'note': serializer.toJson<String?>(note),
      'memo': serializer.toJson<String?>(memo),
      'sourceKey': serializer.toJson<String?>(sourceKey),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  TxnRow copyWith(
          {String? id,
          String? ts,
          String? type,
          String? status,
          String? itemId,
          int? qty,
          String? refType,
          String? refId,
          Value<String?> note = const Value.absent(),
          Value<String?> memo = const Value.absent(),
          Value<String?> sourceKey = const Value.absent(),
          bool? isDeleted,
          Value<String?> deletedAt = const Value.absent()}) =>
      TxnRow(
        id: id ?? this.id,
        ts: ts ?? this.ts,
        type: type ?? this.type,
        status: status ?? this.status,
        itemId: itemId ?? this.itemId,
        qty: qty ?? this.qty,
        refType: refType ?? this.refType,
        refId: refId ?? this.refId,
        note: note.present ? note.value : this.note,
        memo: memo.present ? memo.value : this.memo,
        sourceKey: sourceKey.present ? sourceKey.value : this.sourceKey,
        isDeleted: isDeleted ?? this.isDeleted,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  TxnRow copyWithCompanion(TxnsCompanion data) {
    return TxnRow(
      id: data.id.present ? data.id.value : this.id,
      ts: data.ts.present ? data.ts.value : this.ts,
      type: data.type.present ? data.type.value : this.type,
      status: data.status.present ? data.status.value : this.status,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      qty: data.qty.present ? data.qty.value : this.qty,
      refType: data.refType.present ? data.refType.value : this.refType,
      refId: data.refId.present ? data.refId.value : this.refId,
      note: data.note.present ? data.note.value : this.note,
      memo: data.memo.present ? data.memo.value : this.memo,
      sourceKey: data.sourceKey.present ? data.sourceKey.value : this.sourceKey,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TxnRow(')
          ..write('id: $id, ')
          ..write('ts: $ts, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('itemId: $itemId, ')
          ..write('qty: $qty, ')
          ..write('refType: $refType, ')
          ..write('refId: $refId, ')
          ..write('note: $note, ')
          ..write('memo: $memo, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, ts, type, status, itemId, qty, refType,
      refId, note, memo, sourceKey, isDeleted, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TxnRow &&
          other.id == this.id &&
          other.ts == this.ts &&
          other.type == this.type &&
          other.status == this.status &&
          other.itemId == this.itemId &&
          other.qty == this.qty &&
          other.refType == this.refType &&
          other.refId == this.refId &&
          other.note == this.note &&
          other.memo == this.memo &&
          other.sourceKey == this.sourceKey &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt);
}

class TxnsCompanion extends UpdateCompanion<TxnRow> {
  final Value<String> id;
  final Value<String> ts;
  final Value<String> type;
  final Value<String> status;
  final Value<String> itemId;
  final Value<int> qty;
  final Value<String> refType;
  final Value<String> refId;
  final Value<String?> note;
  final Value<String?> memo;
  final Value<String?> sourceKey;
  final Value<bool> isDeleted;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const TxnsCompanion({
    this.id = const Value.absent(),
    this.ts = const Value.absent(),
    this.type = const Value.absent(),
    this.status = const Value.absent(),
    this.itemId = const Value.absent(),
    this.qty = const Value.absent(),
    this.refType = const Value.absent(),
    this.refId = const Value.absent(),
    this.note = const Value.absent(),
    this.memo = const Value.absent(),
    this.sourceKey = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TxnsCompanion.insert({
    required String id,
    required String ts,
    required String type,
    required String status,
    required String itemId,
    required int qty,
    required String refType,
    required String refId,
    this.note = const Value.absent(),
    this.memo = const Value.absent(),
    this.sourceKey = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        ts = Value(ts),
        type = Value(type),
        status = Value(status),
        itemId = Value(itemId),
        qty = Value(qty),
        refType = Value(refType),
        refId = Value(refId);
  static Insertable<TxnRow> custom({
    Expression<String>? id,
    Expression<String>? ts,
    Expression<String>? type,
    Expression<String>? status,
    Expression<String>? itemId,
    Expression<int>? qty,
    Expression<String>? refType,
    Expression<String>? refId,
    Expression<String>? note,
    Expression<String>? memo,
    Expression<String>? sourceKey,
    Expression<bool>? isDeleted,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ts != null) 'ts': ts,
      if (type != null) 'type': type,
      if (status != null) 'status': status,
      if (itemId != null) 'item_id': itemId,
      if (qty != null) 'qty': qty,
      if (refType != null) 'ref_type': refType,
      if (refId != null) 'ref_id': refId,
      if (note != null) 'note': note,
      if (memo != null) 'memo': memo,
      if (sourceKey != null) 'source_key': sourceKey,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TxnsCompanion copyWith(
      {Value<String>? id,
      Value<String>? ts,
      Value<String>? type,
      Value<String>? status,
      Value<String>? itemId,
      Value<int>? qty,
      Value<String>? refType,
      Value<String>? refId,
      Value<String?>? note,
      Value<String?>? memo,
      Value<String?>? sourceKey,
      Value<bool>? isDeleted,
      Value<String?>? deletedAt,
      Value<int>? rowid}) {
    return TxnsCompanion(
      id: id ?? this.id,
      ts: ts ?? this.ts,
      type: type ?? this.type,
      status: status ?? this.status,
      itemId: itemId ?? this.itemId,
      qty: qty ?? this.qty,
      refType: refType ?? this.refType,
      refId: refId ?? this.refId,
      note: note ?? this.note,
      memo: memo ?? this.memo,
      sourceKey: sourceKey ?? this.sourceKey,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ts.present) {
      map['ts'] = Variable<String>(ts.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (qty.present) {
      map['qty'] = Variable<int>(qty.value);
    }
    if (refType.present) {
      map['ref_type'] = Variable<String>(refType.value);
    }
    if (refId.present) {
      map['ref_id'] = Variable<String>(refId.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (memo.present) {
      map['memo'] = Variable<String>(memo.value);
    }
    if (sourceKey.present) {
      map['source_key'] = Variable<String>(sourceKey.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TxnsCompanion(')
          ..write('id: $id, ')
          ..write('ts: $ts, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('itemId: $itemId, ')
          ..write('qty: $qty, ')
          ..write('refType: $refType, ')
          ..write('refId: $refId, ')
          ..write('note: $note, ')
          ..write('memo: $memo, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BomRowsTable extends BomRows with TableInfo<$BomRowsTable, BomRowDb> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BomRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _rootMeta = const VerificationMeta('root');
  @override
  late final GeneratedColumn<String> root = GeneratedColumn<String>(
      'root', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _parentItemIdMeta =
      const VerificationMeta('parentItemId');
  @override
  late final GeneratedColumn<String> parentItemId = GeneratedColumn<String>(
      'parent_item_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES items (id) ON DELETE CASCADE'));
  static const VerificationMeta _componentItemIdMeta =
      const VerificationMeta('componentItemId');
  @override
  late final GeneratedColumn<String> componentItemId = GeneratedColumn<String>(
      'component_item_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES items (id) ON DELETE CASCADE'));
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _qtyPerMeta = const VerificationMeta('qtyPer');
  @override
  late final GeneratedColumn<double> qtyPer = GeneratedColumn<double>(
      'qty_per', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _wastePctMeta =
      const VerificationMeta('wastePct');
  @override
  late final GeneratedColumn<double> wastePct = GeneratedColumn<double>(
      'waste_pct', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  @override
  List<GeneratedColumn> get $columns =>
      [root, parentItemId, componentItemId, kind, qtyPer, wastePct];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bom_rows';
  @override
  VerificationContext validateIntegrity(Insertable<BomRowDb> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('root')) {
      context.handle(
          _rootMeta, root.isAcceptableOrUnknown(data['root']!, _rootMeta));
    } else if (isInserting) {
      context.missing(_rootMeta);
    }
    if (data.containsKey('parent_item_id')) {
      context.handle(
          _parentItemIdMeta,
          parentItemId.isAcceptableOrUnknown(
              data['parent_item_id']!, _parentItemIdMeta));
    } else if (isInserting) {
      context.missing(_parentItemIdMeta);
    }
    if (data.containsKey('component_item_id')) {
      context.handle(
          _componentItemIdMeta,
          componentItemId.isAcceptableOrUnknown(
              data['component_item_id']!, _componentItemIdMeta));
    } else if (isInserting) {
      context.missing(_componentItemIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('qty_per')) {
      context.handle(_qtyPerMeta,
          qtyPer.isAcceptableOrUnknown(data['qty_per']!, _qtyPerMeta));
    } else if (isInserting) {
      context.missing(_qtyPerMeta);
    }
    if (data.containsKey('waste_pct')) {
      context.handle(_wastePctMeta,
          wastePct.isAcceptableOrUnknown(data['waste_pct']!, _wastePctMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey =>
      {root, parentItemId, componentItemId, kind};
  @override
  BomRowDb map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BomRowDb(
      root: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}root'])!,
      parentItemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parent_item_id'])!,
      componentItemId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}component_item_id'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      qtyPer: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}qty_per'])!,
      wastePct: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}waste_pct'])!,
    );
  }

  @override
  $BomRowsTable createAlias(String alias) {
    return $BomRowsTable(attachedDatabase, alias);
  }
}

class BomRowDb extends DataClass implements Insertable<BomRowDb> {
  final String root;
  final String parentItemId;
  final String componentItemId;
  final String kind;
  final double qtyPer;
  final double wastePct;
  const BomRowDb(
      {required this.root,
      required this.parentItemId,
      required this.componentItemId,
      required this.kind,
      required this.qtyPer,
      required this.wastePct});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['root'] = Variable<String>(root);
    map['parent_item_id'] = Variable<String>(parentItemId);
    map['component_item_id'] = Variable<String>(componentItemId);
    map['kind'] = Variable<String>(kind);
    map['qty_per'] = Variable<double>(qtyPer);
    map['waste_pct'] = Variable<double>(wastePct);
    return map;
  }

  BomRowsCompanion toCompanion(bool nullToAbsent) {
    return BomRowsCompanion(
      root: Value(root),
      parentItemId: Value(parentItemId),
      componentItemId: Value(componentItemId),
      kind: Value(kind),
      qtyPer: Value(qtyPer),
      wastePct: Value(wastePct),
    );
  }

  factory BomRowDb.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BomRowDb(
      root: serializer.fromJson<String>(json['root']),
      parentItemId: serializer.fromJson<String>(json['parentItemId']),
      componentItemId: serializer.fromJson<String>(json['componentItemId']),
      kind: serializer.fromJson<String>(json['kind']),
      qtyPer: serializer.fromJson<double>(json['qtyPer']),
      wastePct: serializer.fromJson<double>(json['wastePct']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'root': serializer.toJson<String>(root),
      'parentItemId': serializer.toJson<String>(parentItemId),
      'componentItemId': serializer.toJson<String>(componentItemId),
      'kind': serializer.toJson<String>(kind),
      'qtyPer': serializer.toJson<double>(qtyPer),
      'wastePct': serializer.toJson<double>(wastePct),
    };
  }

  BomRowDb copyWith(
          {String? root,
          String? parentItemId,
          String? componentItemId,
          String? kind,
          double? qtyPer,
          double? wastePct}) =>
      BomRowDb(
        root: root ?? this.root,
        parentItemId: parentItemId ?? this.parentItemId,
        componentItemId: componentItemId ?? this.componentItemId,
        kind: kind ?? this.kind,
        qtyPer: qtyPer ?? this.qtyPer,
        wastePct: wastePct ?? this.wastePct,
      );
  BomRowDb copyWithCompanion(BomRowsCompanion data) {
    return BomRowDb(
      root: data.root.present ? data.root.value : this.root,
      parentItemId: data.parentItemId.present
          ? data.parentItemId.value
          : this.parentItemId,
      componentItemId: data.componentItemId.present
          ? data.componentItemId.value
          : this.componentItemId,
      kind: data.kind.present ? data.kind.value : this.kind,
      qtyPer: data.qtyPer.present ? data.qtyPer.value : this.qtyPer,
      wastePct: data.wastePct.present ? data.wastePct.value : this.wastePct,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BomRowDb(')
          ..write('root: $root, ')
          ..write('parentItemId: $parentItemId, ')
          ..write('componentItemId: $componentItemId, ')
          ..write('kind: $kind, ')
          ..write('qtyPer: $qtyPer, ')
          ..write('wastePct: $wastePct')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(root, parentItemId, componentItemId, kind, qtyPer, wastePct);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BomRowDb &&
          other.root == this.root &&
          other.parentItemId == this.parentItemId &&
          other.componentItemId == this.componentItemId &&
          other.kind == this.kind &&
          other.qtyPer == this.qtyPer &&
          other.wastePct == this.wastePct);
}

class BomRowsCompanion extends UpdateCompanion<BomRowDb> {
  final Value<String> root;
  final Value<String> parentItemId;
  final Value<String> componentItemId;
  final Value<String> kind;
  final Value<double> qtyPer;
  final Value<double> wastePct;
  final Value<int> rowid;
  const BomRowsCompanion({
    this.root = const Value.absent(),
    this.parentItemId = const Value.absent(),
    this.componentItemId = const Value.absent(),
    this.kind = const Value.absent(),
    this.qtyPer = const Value.absent(),
    this.wastePct = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BomRowsCompanion.insert({
    required String root,
    required String parentItemId,
    required String componentItemId,
    required String kind,
    required double qtyPer,
    this.wastePct = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : root = Value(root),
        parentItemId = Value(parentItemId),
        componentItemId = Value(componentItemId),
        kind = Value(kind),
        qtyPer = Value(qtyPer);
  static Insertable<BomRowDb> custom({
    Expression<String>? root,
    Expression<String>? parentItemId,
    Expression<String>? componentItemId,
    Expression<String>? kind,
    Expression<double>? qtyPer,
    Expression<double>? wastePct,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (root != null) 'root': root,
      if (parentItemId != null) 'parent_item_id': parentItemId,
      if (componentItemId != null) 'component_item_id': componentItemId,
      if (kind != null) 'kind': kind,
      if (qtyPer != null) 'qty_per': qtyPer,
      if (wastePct != null) 'waste_pct': wastePct,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BomRowsCompanion copyWith(
      {Value<String>? root,
      Value<String>? parentItemId,
      Value<String>? componentItemId,
      Value<String>? kind,
      Value<double>? qtyPer,
      Value<double>? wastePct,
      Value<int>? rowid}) {
    return BomRowsCompanion(
      root: root ?? this.root,
      parentItemId: parentItemId ?? this.parentItemId,
      componentItemId: componentItemId ?? this.componentItemId,
      kind: kind ?? this.kind,
      qtyPer: qtyPer ?? this.qtyPer,
      wastePct: wastePct ?? this.wastePct,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (root.present) {
      map['root'] = Variable<String>(root.value);
    }
    if (parentItemId.present) {
      map['parent_item_id'] = Variable<String>(parentItemId.value);
    }
    if (componentItemId.present) {
      map['component_item_id'] = Variable<String>(componentItemId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (qtyPer.present) {
      map['qty_per'] = Variable<double>(qtyPer.value);
    }
    if (wastePct.present) {
      map['waste_pct'] = Variable<double>(wastePct.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BomRowsCompanion(')
          ..write('root: $root, ')
          ..write('parentItemId: $parentItemId, ')
          ..write('componentItemId: $componentItemId, ')
          ..write('kind: $kind, ')
          ..write('qtyPer: $qtyPer, ')
          ..write('wastePct: $wastePct, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OrdersTable extends Orders with TableInfo<$OrdersTable, OrderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OrdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
      'date', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _customerMeta =
      const VerificationMeta('customer');
  @override
  late final GeneratedColumn<String> customer = GeneratedColumn<String>(
      'customer', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _memoMeta = const VerificationMeta('memo');
  @override
  late final GeneratedColumn<String> memo = GeneratedColumn<String>(
      'memo', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _shippedAtMeta =
      const VerificationMeta('shippedAt');
  @override
  late final GeneratedColumn<String> shippedAt = GeneratedColumn<String>(
      'shipped_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _dueDateMeta =
      const VerificationMeta('dueDate');
  @override
  late final GeneratedColumn<String> dueDate = GeneratedColumn<String>(
      'due_date', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        date,
        customer,
        memo,
        status,
        isDeleted,
        updatedAt,
        deletedAt,
        shippedAt,
        dueDate
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'orders';
  @override
  VerificationContext validateIntegrity(Insertable<OrderRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('customer')) {
      context.handle(_customerMeta,
          customer.isAcceptableOrUnknown(data['customer']!, _customerMeta));
    } else if (isInserting) {
      context.missing(_customerMeta);
    }
    if (data.containsKey('memo')) {
      context.handle(
          _memoMeta, memo.isAcceptableOrUnknown(data['memo']!, _memoMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('shipped_at')) {
      context.handle(_shippedAtMeta,
          shippedAt.isAcceptableOrUnknown(data['shipped_at']!, _shippedAtMeta));
    }
    if (data.containsKey('due_date')) {
      context.handle(_dueDateMeta,
          dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OrderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OrderRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}date'])!,
      customer: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}customer'])!,
      memo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}memo']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}updated_at']),
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deleted_at']),
      shippedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}shipped_at']),
      dueDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}due_date']),
    );
  }

  @override
  $OrdersTable createAlias(String alias) {
    return $OrdersTable(attachedDatabase, alias);
  }
}

class OrderRow extends DataClass implements Insertable<OrderRow> {
  final String id;
  final String date;
  final String customer;
  final String? memo;
  final String status;
  final bool isDeleted;
  final String? updatedAt;
  final String? deletedAt;
  final String? shippedAt;
  final String? dueDate;
  const OrderRow(
      {required this.id,
      required this.date,
      required this.customer,
      this.memo,
      required this.status,
      required this.isDeleted,
      this.updatedAt,
      this.deletedAt,
      this.shippedAt,
      this.dueDate});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['date'] = Variable<String>(date);
    map['customer'] = Variable<String>(customer);
    if (!nullToAbsent || memo != null) {
      map['memo'] = Variable<String>(memo);
    }
    map['status'] = Variable<String>(status);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    if (!nullToAbsent || shippedAt != null) {
      map['shipped_at'] = Variable<String>(shippedAt);
    }
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<String>(dueDate);
    }
    return map;
  }

  OrdersCompanion toCompanion(bool nullToAbsent) {
    return OrdersCompanion(
      id: Value(id),
      date: Value(date),
      customer: Value(customer),
      memo: memo == null && nullToAbsent ? const Value.absent() : Value(memo),
      status: Value(status),
      isDeleted: Value(isDeleted),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      shippedAt: shippedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(shippedAt),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
    );
  }

  factory OrderRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OrderRow(
      id: serializer.fromJson<String>(json['id']),
      date: serializer.fromJson<String>(json['date']),
      customer: serializer.fromJson<String>(json['customer']),
      memo: serializer.fromJson<String?>(json['memo']),
      status: serializer.fromJson<String>(json['status']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      shippedAt: serializer.fromJson<String?>(json['shippedAt']),
      dueDate: serializer.fromJson<String?>(json['dueDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'date': serializer.toJson<String>(date),
      'customer': serializer.toJson<String>(customer),
      'memo': serializer.toJson<String?>(memo),
      'status': serializer.toJson<String>(status),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'updatedAt': serializer.toJson<String?>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'shippedAt': serializer.toJson<String?>(shippedAt),
      'dueDate': serializer.toJson<String?>(dueDate),
    };
  }

  OrderRow copyWith(
          {String? id,
          String? date,
          String? customer,
          Value<String?> memo = const Value.absent(),
          String? status,
          bool? isDeleted,
          Value<String?> updatedAt = const Value.absent(),
          Value<String?> deletedAt = const Value.absent(),
          Value<String?> shippedAt = const Value.absent(),
          Value<String?> dueDate = const Value.absent()}) =>
      OrderRow(
        id: id ?? this.id,
        date: date ?? this.date,
        customer: customer ?? this.customer,
        memo: memo.present ? memo.value : this.memo,
        status: status ?? this.status,
        isDeleted: isDeleted ?? this.isDeleted,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        shippedAt: shippedAt.present ? shippedAt.value : this.shippedAt,
        dueDate: dueDate.present ? dueDate.value : this.dueDate,
      );
  OrderRow copyWithCompanion(OrdersCompanion data) {
    return OrderRow(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      customer: data.customer.present ? data.customer.value : this.customer,
      memo: data.memo.present ? data.memo.value : this.memo,
      status: data.status.present ? data.status.value : this.status,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      shippedAt: data.shippedAt.present ? data.shippedAt.value : this.shippedAt,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OrderRow(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('customer: $customer, ')
          ..write('memo: $memo, ')
          ..write('status: $status, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('shippedAt: $shippedAt, ')
          ..write('dueDate: $dueDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, date, customer, memo, status, isDeleted,
      updatedAt, deletedAt, shippedAt, dueDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrderRow &&
          other.id == this.id &&
          other.date == this.date &&
          other.customer == this.customer &&
          other.memo == this.memo &&
          other.status == this.status &&
          other.isDeleted == this.isDeleted &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.shippedAt == this.shippedAt &&
          other.dueDate == this.dueDate);
}

class OrdersCompanion extends UpdateCompanion<OrderRow> {
  final Value<String> id;
  final Value<String> date;
  final Value<String> customer;
  final Value<String?> memo;
  final Value<String> status;
  final Value<bool> isDeleted;
  final Value<String?> updatedAt;
  final Value<String?> deletedAt;
  final Value<String?> shippedAt;
  final Value<String?> dueDate;
  final Value<int> rowid;
  const OrdersCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.customer = const Value.absent(),
    this.memo = const Value.absent(),
    this.status = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.shippedAt = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OrdersCompanion.insert({
    required String id,
    required String date,
    required String customer,
    this.memo = const Value.absent(),
    required String status,
    this.isDeleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.shippedAt = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        date = Value(date),
        customer = Value(customer),
        status = Value(status);
  static Insertable<OrderRow> custom({
    Expression<String>? id,
    Expression<String>? date,
    Expression<String>? customer,
    Expression<String>? memo,
    Expression<String>? status,
    Expression<bool>? isDeleted,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<String>? shippedAt,
    Expression<String>? dueDate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (customer != null) 'customer': customer,
      if (memo != null) 'memo': memo,
      if (status != null) 'status': status,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (shippedAt != null) 'shipped_at': shippedAt,
      if (dueDate != null) 'due_date': dueDate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OrdersCompanion copyWith(
      {Value<String>? id,
      Value<String>? date,
      Value<String>? customer,
      Value<String?>? memo,
      Value<String>? status,
      Value<bool>? isDeleted,
      Value<String?>? updatedAt,
      Value<String?>? deletedAt,
      Value<String?>? shippedAt,
      Value<String?>? dueDate,
      Value<int>? rowid}) {
    return OrdersCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      customer: customer ?? this.customer,
      memo: memo ?? this.memo,
      status: status ?? this.status,
      isDeleted: isDeleted ?? this.isDeleted,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      shippedAt: shippedAt ?? this.shippedAt,
      dueDate: dueDate ?? this.dueDate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (customer.present) {
      map['customer'] = Variable<String>(customer.value);
    }
    if (memo.present) {
      map['memo'] = Variable<String>(memo.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (shippedAt.present) {
      map['shipped_at'] = Variable<String>(shippedAt.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<String>(dueDate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OrdersCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('customer: $customer, ')
          ..write('memo: $memo, ')
          ..write('status: $status, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('shippedAt: $shippedAt, ')
          ..write('dueDate: $dueDate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OrderLinesTable extends OrderLines
    with TableInfo<$OrderLinesTable, OrderLineRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OrderLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _orderIdMeta =
      const VerificationMeta('orderId');
  @override
  late final GeneratedColumn<String> orderId = GeneratedColumn<String>(
      'order_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES orders (id) ON DELETE CASCADE'));
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
      'item_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES items (id) ON DELETE RESTRICT'));
  static const VerificationMeta _qtyMeta = const VerificationMeta('qty');
  @override
  late final GeneratedColumn<int> qty = GeneratedColumn<int>(
      'qty', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, orderId, itemId, qty, isDeleted, deletedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'order_lines';
  @override
  VerificationContext validateIntegrity(Insertable<OrderLineRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('order_id')) {
      context.handle(_orderIdMeta,
          orderId.isAcceptableOrUnknown(data['order_id']!, _orderIdMeta));
    } else if (isInserting) {
      context.missing(_orderIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('qty')) {
      context.handle(
          _qtyMeta, qty.isAcceptableOrUnknown(data['qty']!, _qtyMeta));
    } else if (isInserting) {
      context.missing(_qtyMeta);
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OrderLineRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OrderLineRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      orderId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}order_id'])!,
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      qty: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}qty'])!,
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $OrderLinesTable createAlias(String alias) {
    return $OrderLinesTable(attachedDatabase, alias);
  }
}

class OrderLineRow extends DataClass implements Insertable<OrderLineRow> {
  final String id;
  final String orderId;
  final String itemId;
  final int qty;
  final bool isDeleted;
  final String? deletedAt;
  const OrderLineRow(
      {required this.id,
      required this.orderId,
      required this.itemId,
      required this.qty,
      required this.isDeleted,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['order_id'] = Variable<String>(orderId);
    map['item_id'] = Variable<String>(itemId);
    map['qty'] = Variable<int>(qty);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  OrderLinesCompanion toCompanion(bool nullToAbsent) {
    return OrderLinesCompanion(
      id: Value(id),
      orderId: Value(orderId),
      itemId: Value(itemId),
      qty: Value(qty),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory OrderLineRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OrderLineRow(
      id: serializer.fromJson<String>(json['id']),
      orderId: serializer.fromJson<String>(json['orderId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      qty: serializer.fromJson<int>(json['qty']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'orderId': serializer.toJson<String>(orderId),
      'itemId': serializer.toJson<String>(itemId),
      'qty': serializer.toJson<int>(qty),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  OrderLineRow copyWith(
          {String? id,
          String? orderId,
          String? itemId,
          int? qty,
          bool? isDeleted,
          Value<String?> deletedAt = const Value.absent()}) =>
      OrderLineRow(
        id: id ?? this.id,
        orderId: orderId ?? this.orderId,
        itemId: itemId ?? this.itemId,
        qty: qty ?? this.qty,
        isDeleted: isDeleted ?? this.isDeleted,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  OrderLineRow copyWithCompanion(OrderLinesCompanion data) {
    return OrderLineRow(
      id: data.id.present ? data.id.value : this.id,
      orderId: data.orderId.present ? data.orderId.value : this.orderId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      qty: data.qty.present ? data.qty.value : this.qty,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OrderLineRow(')
          ..write('id: $id, ')
          ..write('orderId: $orderId, ')
          ..write('itemId: $itemId, ')
          ..write('qty: $qty, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, orderId, itemId, qty, isDeleted, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrderLineRow &&
          other.id == this.id &&
          other.orderId == this.orderId &&
          other.itemId == this.itemId &&
          other.qty == this.qty &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt);
}

class OrderLinesCompanion extends UpdateCompanion<OrderLineRow> {
  final Value<String> id;
  final Value<String> orderId;
  final Value<String> itemId;
  final Value<int> qty;
  final Value<bool> isDeleted;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const OrderLinesCompanion({
    this.id = const Value.absent(),
    this.orderId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.qty = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OrderLinesCompanion.insert({
    required String id,
    required String orderId,
    required String itemId,
    required int qty,
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        orderId = Value(orderId),
        itemId = Value(itemId),
        qty = Value(qty);
  static Insertable<OrderLineRow> custom({
    Expression<String>? id,
    Expression<String>? orderId,
    Expression<String>? itemId,
    Expression<int>? qty,
    Expression<bool>? isDeleted,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (orderId != null) 'order_id': orderId,
      if (itemId != null) 'item_id': itemId,
      if (qty != null) 'qty': qty,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OrderLinesCompanion copyWith(
      {Value<String>? id,
      Value<String>? orderId,
      Value<String>? itemId,
      Value<int>? qty,
      Value<bool>? isDeleted,
      Value<String?>? deletedAt,
      Value<int>? rowid}) {
    return OrderLinesCompanion(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      itemId: itemId ?? this.itemId,
      qty: qty ?? this.qty,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (orderId.present) {
      map['order_id'] = Variable<String>(orderId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (qty.present) {
      map['qty'] = Variable<int>(qty.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OrderLinesCompanion(')
          ..write('id: $id, ')
          ..write('orderId: $orderId, ')
          ..write('itemId: $itemId, ')
          ..write('qty: $qty, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorksTable extends Works with TableInfo<$WorksTable, WorkRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
      'item_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES items (id) ON DELETE RESTRICT'));
  static const VerificationMeta _qtyMeta = const VerificationMeta('qty');
  @override
  late final GeneratedColumn<int> qty = GeneratedColumn<int>(
      'qty', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _doneQtyMeta =
      const VerificationMeta('doneQty');
  @override
  late final GeneratedColumn<int> doneQty = GeneratedColumn<int>(
      'done_qty', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _orderIdMeta =
      const VerificationMeta('orderId');
  @override
  late final GeneratedColumn<String> orderId = GeneratedColumn<String>(
      'order_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES orders (id) ON DELETE SET NULL'));
  static const VerificationMeta _parentWorkIdMeta =
      const VerificationMeta('parentWorkId');
  @override
  late final GeneratedColumn<String> parentWorkId = GeneratedColumn<String>(
      'parent_work_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
      'created_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceKeyMeta =
      const VerificationMeta('sourceKey');
  @override
  late final GeneratedColumn<String> sourceKey = GeneratedColumn<String>(
      'source_key', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<String> startedAt = GeneratedColumn<String>(
      'started_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _finishedAtMeta =
      const VerificationMeta('finishedAt');
  @override
  late final GeneratedColumn<String> finishedAt = GeneratedColumn<String>(
      'finished_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        itemId,
        qty,
        doneQty,
        orderId,
        parentWorkId,
        status,
        createdAt,
        updatedAt,
        sourceKey,
        isDeleted,
        deletedAt,
        startedAt,
        finishedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'works';
  @override
  VerificationContext validateIntegrity(Insertable<WorkRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('qty')) {
      context.handle(
          _qtyMeta, qty.isAcceptableOrUnknown(data['qty']!, _qtyMeta));
    } else if (isInserting) {
      context.missing(_qtyMeta);
    }
    if (data.containsKey('done_qty')) {
      context.handle(_doneQtyMeta,
          doneQty.isAcceptableOrUnknown(data['done_qty']!, _doneQtyMeta));
    }
    if (data.containsKey('order_id')) {
      context.handle(_orderIdMeta,
          orderId.isAcceptableOrUnknown(data['order_id']!, _orderIdMeta));
    }
    if (data.containsKey('parent_work_id')) {
      context.handle(
          _parentWorkIdMeta,
          parentWorkId.isAcceptableOrUnknown(
              data['parent_work_id']!, _parentWorkIdMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('source_key')) {
      context.handle(_sourceKeyMeta,
          sourceKey.isAcceptableOrUnknown(data['source_key']!, _sourceKeyMeta));
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    }
    if (data.containsKey('finished_at')) {
      context.handle(
          _finishedAtMeta,
          finishedAt.isAcceptableOrUnknown(
              data['finished_at']!, _finishedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      qty: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}qty'])!,
      doneQty: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}done_qty'])!,
      orderId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}order_id']),
      parentWorkId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parent_work_id']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}updated_at']),
      sourceKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_key']),
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deleted_at']),
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}started_at']),
      finishedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}finished_at']),
    );
  }

  @override
  $WorksTable createAlias(String alias) {
    return $WorksTable(attachedDatabase, alias);
  }
}

class WorkRow extends DataClass implements Insertable<WorkRow> {
  final String id;
  final String itemId;
  final int qty;
  final int doneQty;
  final String? orderId;
  final String? parentWorkId;
  final String status;
  final String createdAt;
  final String? updatedAt;
  final String? sourceKey;
  final bool isDeleted;
  final String? deletedAt;
  final String? startedAt;
  final String? finishedAt;
  const WorkRow(
      {required this.id,
      required this.itemId,
      required this.qty,
      required this.doneQty,
      this.orderId,
      this.parentWorkId,
      required this.status,
      required this.createdAt,
      this.updatedAt,
      this.sourceKey,
      required this.isDeleted,
      this.deletedAt,
      this.startedAt,
      this.finishedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['item_id'] = Variable<String>(itemId);
    map['qty'] = Variable<int>(qty);
    map['done_qty'] = Variable<int>(doneQty);
    if (!nullToAbsent || orderId != null) {
      map['order_id'] = Variable<String>(orderId);
    }
    if (!nullToAbsent || parentWorkId != null) {
      map['parent_work_id'] = Variable<String>(parentWorkId);
    }
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<String>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    if (!nullToAbsent || sourceKey != null) {
      map['source_key'] = Variable<String>(sourceKey);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<String>(startedAt);
    }
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<String>(finishedAt);
    }
    return map;
  }

  WorksCompanion toCompanion(bool nullToAbsent) {
    return WorksCompanion(
      id: Value(id),
      itemId: Value(itemId),
      qty: Value(qty),
      doneQty: Value(doneQty),
      orderId: orderId == null && nullToAbsent
          ? const Value.absent()
          : Value(orderId),
      parentWorkId: parentWorkId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentWorkId),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      sourceKey: sourceKey == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceKey),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
    );
  }

  factory WorkRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkRow(
      id: serializer.fromJson<String>(json['id']),
      itemId: serializer.fromJson<String>(json['itemId']),
      qty: serializer.fromJson<int>(json['qty']),
      doneQty: serializer.fromJson<int>(json['doneQty']),
      orderId: serializer.fromJson<String?>(json['orderId']),
      parentWorkId: serializer.fromJson<String?>(json['parentWorkId']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
      sourceKey: serializer.fromJson<String?>(json['sourceKey']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      startedAt: serializer.fromJson<String?>(json['startedAt']),
      finishedAt: serializer.fromJson<String?>(json['finishedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'itemId': serializer.toJson<String>(itemId),
      'qty': serializer.toJson<int>(qty),
      'doneQty': serializer.toJson<int>(doneQty),
      'orderId': serializer.toJson<String?>(orderId),
      'parentWorkId': serializer.toJson<String?>(parentWorkId),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String?>(updatedAt),
      'sourceKey': serializer.toJson<String?>(sourceKey),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'startedAt': serializer.toJson<String?>(startedAt),
      'finishedAt': serializer.toJson<String?>(finishedAt),
    };
  }

  WorkRow copyWith(
          {String? id,
          String? itemId,
          int? qty,
          int? doneQty,
          Value<String?> orderId = const Value.absent(),
          Value<String?> parentWorkId = const Value.absent(),
          String? status,
          String? createdAt,
          Value<String?> updatedAt = const Value.absent(),
          Value<String?> sourceKey = const Value.absent(),
          bool? isDeleted,
          Value<String?> deletedAt = const Value.absent(),
          Value<String?> startedAt = const Value.absent(),
          Value<String?> finishedAt = const Value.absent()}) =>
      WorkRow(
        id: id ?? this.id,
        itemId: itemId ?? this.itemId,
        qty: qty ?? this.qty,
        doneQty: doneQty ?? this.doneQty,
        orderId: orderId.present ? orderId.value : this.orderId,
        parentWorkId:
            parentWorkId.present ? parentWorkId.value : this.parentWorkId,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
        sourceKey: sourceKey.present ? sourceKey.value : this.sourceKey,
        isDeleted: isDeleted ?? this.isDeleted,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        startedAt: startedAt.present ? startedAt.value : this.startedAt,
        finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
      );
  WorkRow copyWithCompanion(WorksCompanion data) {
    return WorkRow(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      qty: data.qty.present ? data.qty.value : this.qty,
      doneQty: data.doneQty.present ? data.doneQty.value : this.doneQty,
      orderId: data.orderId.present ? data.orderId.value : this.orderId,
      parentWorkId: data.parentWorkId.present
          ? data.parentWorkId.value
          : this.parentWorkId,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      sourceKey: data.sourceKey.present ? data.sourceKey.value : this.sourceKey,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt:
          data.finishedAt.present ? data.finishedAt.value : this.finishedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkRow(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('qty: $qty, ')
          ..write('doneQty: $doneQty, ')
          ..write('orderId: $orderId, ')
          ..write('parentWorkId: $parentWorkId, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      itemId,
      qty,
      doneQty,
      orderId,
      parentWorkId,
      status,
      createdAt,
      updatedAt,
      sourceKey,
      isDeleted,
      deletedAt,
      startedAt,
      finishedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkRow &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.qty == this.qty &&
          other.doneQty == this.doneQty &&
          other.orderId == this.orderId &&
          other.parentWorkId == this.parentWorkId &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.sourceKey == this.sourceKey &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt);
}

class WorksCompanion extends UpdateCompanion<WorkRow> {
  final Value<String> id;
  final Value<String> itemId;
  final Value<int> qty;
  final Value<int> doneQty;
  final Value<String?> orderId;
  final Value<String?> parentWorkId;
  final Value<String> status;
  final Value<String> createdAt;
  final Value<String?> updatedAt;
  final Value<String?> sourceKey;
  final Value<bool> isDeleted;
  final Value<String?> deletedAt;
  final Value<String?> startedAt;
  final Value<String?> finishedAt;
  final Value<int> rowid;
  const WorksCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.qty = const Value.absent(),
    this.doneQty = const Value.absent(),
    this.orderId = const Value.absent(),
    this.parentWorkId = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.sourceKey = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorksCompanion.insert({
    required String id,
    required String itemId,
    required int qty,
    this.doneQty = const Value.absent(),
    this.orderId = const Value.absent(),
    this.parentWorkId = const Value.absent(),
    required String status,
    required String createdAt,
    this.updatedAt = const Value.absent(),
    this.sourceKey = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        itemId = Value(itemId),
        qty = Value(qty),
        status = Value(status),
        createdAt = Value(createdAt);
  static Insertable<WorkRow> custom({
    Expression<String>? id,
    Expression<String>? itemId,
    Expression<int>? qty,
    Expression<int>? doneQty,
    Expression<String>? orderId,
    Expression<String>? parentWorkId,
    Expression<String>? status,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? sourceKey,
    Expression<bool>? isDeleted,
    Expression<String>? deletedAt,
    Expression<String>? startedAt,
    Expression<String>? finishedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (qty != null) 'qty': qty,
      if (doneQty != null) 'done_qty': doneQty,
      if (orderId != null) 'order_id': orderId,
      if (parentWorkId != null) 'parent_work_id': parentWorkId,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (sourceKey != null) 'source_key': sourceKey,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorksCompanion copyWith(
      {Value<String>? id,
      Value<String>? itemId,
      Value<int>? qty,
      Value<int>? doneQty,
      Value<String?>? orderId,
      Value<String?>? parentWorkId,
      Value<String>? status,
      Value<String>? createdAt,
      Value<String?>? updatedAt,
      Value<String?>? sourceKey,
      Value<bool>? isDeleted,
      Value<String?>? deletedAt,
      Value<String?>? startedAt,
      Value<String?>? finishedAt,
      Value<int>? rowid}) {
    return WorksCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      qty: qty ?? this.qty,
      doneQty: doneQty ?? this.doneQty,
      orderId: orderId ?? this.orderId,
      parentWorkId: parentWorkId ?? this.parentWorkId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sourceKey: sourceKey ?? this.sourceKey,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (qty.present) {
      map['qty'] = Variable<int>(qty.value);
    }
    if (doneQty.present) {
      map['done_qty'] = Variable<int>(doneQty.value);
    }
    if (orderId.present) {
      map['order_id'] = Variable<String>(orderId.value);
    }
    if (parentWorkId.present) {
      map['parent_work_id'] = Variable<String>(parentWorkId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (sourceKey.present) {
      map['source_key'] = Variable<String>(sourceKey.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<String>(startedAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<String>(finishedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorksCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('qty: $qty, ')
          ..write('doneQty: $doneQty, ')
          ..write('orderId: $orderId, ')
          ..write('parentWorkId: $parentWorkId, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PurchaseOrdersTable extends PurchaseOrders
    with TableInfo<$PurchaseOrdersTable, PurchaseOrderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PurchaseOrdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _supplierNameMeta =
      const VerificationMeta('supplierName');
  @override
  late final GeneratedColumn<String> supplierName = GeneratedColumn<String>(
      'supplier_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _etaMeta = const VerificationMeta('eta');
  @override
  late final GeneratedColumn<String> eta = GeneratedColumn<String>(
      'eta', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
      'created_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _memoMeta = const VerificationMeta('memo');
  @override
  late final GeneratedColumn<String> memo = GeneratedColumn<String>(
      'memo', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _orderIdMeta =
      const VerificationMeta('orderId');
  @override
  late final GeneratedColumn<String> orderId = GeneratedColumn<String>(
      'order_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _receivedAtMeta =
      const VerificationMeta('receivedAt');
  @override
  late final GeneratedColumn<String> receivedAt = GeneratedColumn<String>(
      'received_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        supplierName,
        eta,
        status,
        createdAt,
        updatedAt,
        isDeleted,
        memo,
        deletedAt,
        orderId,
        receivedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'purchase_orders';
  @override
  VerificationContext validateIntegrity(Insertable<PurchaseOrderRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('supplier_name')) {
      context.handle(
          _supplierNameMeta,
          supplierName.isAcceptableOrUnknown(
              data['supplier_name']!, _supplierNameMeta));
    } else if (isInserting) {
      context.missing(_supplierNameMeta);
    }
    if (data.containsKey('eta')) {
      context.handle(
          _etaMeta, eta.isAcceptableOrUnknown(data['eta']!, _etaMeta));
    } else if (isInserting) {
      context.missing(_etaMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    if (data.containsKey('memo')) {
      context.handle(
          _memoMeta, memo.isAcceptableOrUnknown(data['memo']!, _memoMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('order_id')) {
      context.handle(_orderIdMeta,
          orderId.isAcceptableOrUnknown(data['order_id']!, _orderIdMeta));
    }
    if (data.containsKey('received_at')) {
      context.handle(
          _receivedAtMeta,
          receivedAt.isAcceptableOrUnknown(
              data['received_at']!, _receivedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PurchaseOrderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PurchaseOrderRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      supplierName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}supplier_name'])!,
      eta: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}eta'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}updated_at'])!,
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
      memo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}memo']),
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deleted_at']),
      orderId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}order_id']),
      receivedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}received_at']),
    );
  }

  @override
  $PurchaseOrdersTable createAlias(String alias) {
    return $PurchaseOrdersTable(attachedDatabase, alias);
  }
}

class PurchaseOrderRow extends DataClass
    implements Insertable<PurchaseOrderRow> {
  final String id;
  final String supplierName;
  final String eta;
  final String status;
  final String createdAt;
  final String updatedAt;
  final bool isDeleted;
  final String? memo;
  final String? deletedAt;
  final String? orderId;
  final String? receivedAt;
  const PurchaseOrderRow(
      {required this.id,
      required this.supplierName,
      required this.eta,
      required this.status,
      required this.createdAt,
      required this.updatedAt,
      required this.isDeleted,
      this.memo,
      this.deletedAt,
      this.orderId,
      this.receivedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['supplier_name'] = Variable<String>(supplierName);
    map['eta'] = Variable<String>(eta);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || memo != null) {
      map['memo'] = Variable<String>(memo);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    if (!nullToAbsent || orderId != null) {
      map['order_id'] = Variable<String>(orderId);
    }
    if (!nullToAbsent || receivedAt != null) {
      map['received_at'] = Variable<String>(receivedAt);
    }
    return map;
  }

  PurchaseOrdersCompanion toCompanion(bool nullToAbsent) {
    return PurchaseOrdersCompanion(
      id: Value(id),
      supplierName: Value(supplierName),
      eta: Value(eta),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
      memo: memo == null && nullToAbsent ? const Value.absent() : Value(memo),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      orderId: orderId == null && nullToAbsent
          ? const Value.absent()
          : Value(orderId),
      receivedAt: receivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(receivedAt),
    );
  }

  factory PurchaseOrderRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PurchaseOrderRow(
      id: serializer.fromJson<String>(json['id']),
      supplierName: serializer.fromJson<String>(json['supplierName']),
      eta: serializer.fromJson<String>(json['eta']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      memo: serializer.fromJson<String?>(json['memo']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      orderId: serializer.fromJson<String?>(json['orderId']),
      receivedAt: serializer.fromJson<String?>(json['receivedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'supplierName': serializer.toJson<String>(supplierName),
      'eta': serializer.toJson<String>(eta),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'memo': serializer.toJson<String?>(memo),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'orderId': serializer.toJson<String?>(orderId),
      'receivedAt': serializer.toJson<String?>(receivedAt),
    };
  }

  PurchaseOrderRow copyWith(
          {String? id,
          String? supplierName,
          String? eta,
          String? status,
          String? createdAt,
          String? updatedAt,
          bool? isDeleted,
          Value<String?> memo = const Value.absent(),
          Value<String?> deletedAt = const Value.absent(),
          Value<String?> orderId = const Value.absent(),
          Value<String?> receivedAt = const Value.absent()}) =>
      PurchaseOrderRow(
        id: id ?? this.id,
        supplierName: supplierName ?? this.supplierName,
        eta: eta ?? this.eta,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isDeleted: isDeleted ?? this.isDeleted,
        memo: memo.present ? memo.value : this.memo,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        orderId: orderId.present ? orderId.value : this.orderId,
        receivedAt: receivedAt.present ? receivedAt.value : this.receivedAt,
      );
  PurchaseOrderRow copyWithCompanion(PurchaseOrdersCompanion data) {
    return PurchaseOrderRow(
      id: data.id.present ? data.id.value : this.id,
      supplierName: data.supplierName.present
          ? data.supplierName.value
          : this.supplierName,
      eta: data.eta.present ? data.eta.value : this.eta,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      memo: data.memo.present ? data.memo.value : this.memo,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      orderId: data.orderId.present ? data.orderId.value : this.orderId,
      receivedAt:
          data.receivedAt.present ? data.receivedAt.value : this.receivedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PurchaseOrderRow(')
          ..write('id: $id, ')
          ..write('supplierName: $supplierName, ')
          ..write('eta: $eta, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('memo: $memo, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('orderId: $orderId, ')
          ..write('receivedAt: $receivedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, supplierName, eta, status, createdAt,
      updatedAt, isDeleted, memo, deletedAt, orderId, receivedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PurchaseOrderRow &&
          other.id == this.id &&
          other.supplierName == this.supplierName &&
          other.eta == this.eta &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isDeleted == this.isDeleted &&
          other.memo == this.memo &&
          other.deletedAt == this.deletedAt &&
          other.orderId == this.orderId &&
          other.receivedAt == this.receivedAt);
}

class PurchaseOrdersCompanion extends UpdateCompanion<PurchaseOrderRow> {
  final Value<String> id;
  final Value<String> supplierName;
  final Value<String> eta;
  final Value<String> status;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<bool> isDeleted;
  final Value<String?> memo;
  final Value<String?> deletedAt;
  final Value<String?> orderId;
  final Value<String?> receivedAt;
  final Value<int> rowid;
  const PurchaseOrdersCompanion({
    this.id = const Value.absent(),
    this.supplierName = const Value.absent(),
    this.eta = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.memo = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.orderId = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PurchaseOrdersCompanion.insert({
    required String id,
    required String supplierName,
    required String eta,
    required String status,
    required String createdAt,
    required String updatedAt,
    this.isDeleted = const Value.absent(),
    this.memo = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.orderId = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        supplierName = Value(supplierName),
        eta = Value(eta),
        status = Value(status),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<PurchaseOrderRow> custom({
    Expression<String>? id,
    Expression<String>? supplierName,
    Expression<String>? eta,
    Expression<String>? status,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<bool>? isDeleted,
    Expression<String>? memo,
    Expression<String>? deletedAt,
    Expression<String>? orderId,
    Expression<String>? receivedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (supplierName != null) 'supplier_name': supplierName,
      if (eta != null) 'eta': eta,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (memo != null) 'memo': memo,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (orderId != null) 'order_id': orderId,
      if (receivedAt != null) 'received_at': receivedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PurchaseOrdersCompanion copyWith(
      {Value<String>? id,
      Value<String>? supplierName,
      Value<String>? eta,
      Value<String>? status,
      Value<String>? createdAt,
      Value<String>? updatedAt,
      Value<bool>? isDeleted,
      Value<String?>? memo,
      Value<String?>? deletedAt,
      Value<String?>? orderId,
      Value<String?>? receivedAt,
      Value<int>? rowid}) {
    return PurchaseOrdersCompanion(
      id: id ?? this.id,
      supplierName: supplierName ?? this.supplierName,
      eta: eta ?? this.eta,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      memo: memo ?? this.memo,
      deletedAt: deletedAt ?? this.deletedAt,
      orderId: orderId ?? this.orderId,
      receivedAt: receivedAt ?? this.receivedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (supplierName.present) {
      map['supplier_name'] = Variable<String>(supplierName.value);
    }
    if (eta.present) {
      map['eta'] = Variable<String>(eta.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (memo.present) {
      map['memo'] = Variable<String>(memo.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (orderId.present) {
      map['order_id'] = Variable<String>(orderId.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<String>(receivedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PurchaseOrdersCompanion(')
          ..write('id: $id, ')
          ..write('supplierName: $supplierName, ')
          ..write('eta: $eta, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('memo: $memo, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('orderId: $orderId, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PurchaseLinesTable extends PurchaseLines
    with TableInfo<$PurchaseLinesTable, PurchaseLineRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PurchaseLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _orderIdMeta =
      const VerificationMeta('orderId');
  @override
  late final GeneratedColumn<String> orderId = GeneratedColumn<String>(
      'order_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES purchase_orders (id) ON DELETE CASCADE'));
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
      'item_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES items (id) ON DELETE RESTRICT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
      'unit', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _qtyMeta = const VerificationMeta('qty');
  @override
  late final GeneratedColumn<double> qty = GeneratedColumn<double>(
      'qty', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _memoMeta = const VerificationMeta('memo');
  @override
  late final GeneratedColumn<String> memo = GeneratedColumn<String>(
      'memo', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _colorNoMeta =
      const VerificationMeta('colorNo');
  @override
  late final GeneratedColumn<String> colorNo = GeneratedColumn<String>(
      'color_no', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        orderId,
        itemId,
        name,
        unit,
        qty,
        note,
        memo,
        colorNo,
        isDeleted,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'purchase_lines';
  @override
  VerificationContext validateIntegrity(Insertable<PurchaseLineRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('order_id')) {
      context.handle(_orderIdMeta,
          orderId.isAcceptableOrUnknown(data['order_id']!, _orderIdMeta));
    } else if (isInserting) {
      context.missing(_orderIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
          _unitMeta, unit.isAcceptableOrUnknown(data['unit']!, _unitMeta));
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('qty')) {
      context.handle(
          _qtyMeta, qty.isAcceptableOrUnknown(data['qty']!, _qtyMeta));
    } else if (isInserting) {
      context.missing(_qtyMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('memo')) {
      context.handle(
          _memoMeta, memo.isAcceptableOrUnknown(data['memo']!, _memoMeta));
    }
    if (data.containsKey('color_no')) {
      context.handle(_colorNoMeta,
          colorNo.isAcceptableOrUnknown(data['color_no']!, _colorNoMeta));
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PurchaseLineRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PurchaseLineRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      orderId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}order_id'])!,
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      unit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unit'])!,
      qty: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}qty'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      memo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}memo']),
      colorNo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}color_no']),
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $PurchaseLinesTable createAlias(String alias) {
    return $PurchaseLinesTable(attachedDatabase, alias);
  }
}

class PurchaseLineRow extends DataClass implements Insertable<PurchaseLineRow> {
  final String id;
  final String orderId;
  final String itemId;
  final String name;
  final String unit;
  final double qty;
  final String? note;
  final String? memo;
  final String? colorNo;
  final bool isDeleted;
  final String? deletedAt;
  const PurchaseLineRow(
      {required this.id,
      required this.orderId,
      required this.itemId,
      required this.name,
      required this.unit,
      required this.qty,
      this.note,
      this.memo,
      this.colorNo,
      required this.isDeleted,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['order_id'] = Variable<String>(orderId);
    map['item_id'] = Variable<String>(itemId);
    map['name'] = Variable<String>(name);
    map['unit'] = Variable<String>(unit);
    map['qty'] = Variable<double>(qty);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || memo != null) {
      map['memo'] = Variable<String>(memo);
    }
    if (!nullToAbsent || colorNo != null) {
      map['color_no'] = Variable<String>(colorNo);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  PurchaseLinesCompanion toCompanion(bool nullToAbsent) {
    return PurchaseLinesCompanion(
      id: Value(id),
      orderId: Value(orderId),
      itemId: Value(itemId),
      name: Value(name),
      unit: Value(unit),
      qty: Value(qty),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      memo: memo == null && nullToAbsent ? const Value.absent() : Value(memo),
      colorNo: colorNo == null && nullToAbsent
          ? const Value.absent()
          : Value(colorNo),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory PurchaseLineRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PurchaseLineRow(
      id: serializer.fromJson<String>(json['id']),
      orderId: serializer.fromJson<String>(json['orderId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      name: serializer.fromJson<String>(json['name']),
      unit: serializer.fromJson<String>(json['unit']),
      qty: serializer.fromJson<double>(json['qty']),
      note: serializer.fromJson<String?>(json['note']),
      memo: serializer.fromJson<String?>(json['memo']),
      colorNo: serializer.fromJson<String?>(json['colorNo']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'orderId': serializer.toJson<String>(orderId),
      'itemId': serializer.toJson<String>(itemId),
      'name': serializer.toJson<String>(name),
      'unit': serializer.toJson<String>(unit),
      'qty': serializer.toJson<double>(qty),
      'note': serializer.toJson<String?>(note),
      'memo': serializer.toJson<String?>(memo),
      'colorNo': serializer.toJson<String?>(colorNo),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  PurchaseLineRow copyWith(
          {String? id,
          String? orderId,
          String? itemId,
          String? name,
          String? unit,
          double? qty,
          Value<String?> note = const Value.absent(),
          Value<String?> memo = const Value.absent(),
          Value<String?> colorNo = const Value.absent(),
          bool? isDeleted,
          Value<String?> deletedAt = const Value.absent()}) =>
      PurchaseLineRow(
        id: id ?? this.id,
        orderId: orderId ?? this.orderId,
        itemId: itemId ?? this.itemId,
        name: name ?? this.name,
        unit: unit ?? this.unit,
        qty: qty ?? this.qty,
        note: note.present ? note.value : this.note,
        memo: memo.present ? memo.value : this.memo,
        colorNo: colorNo.present ? colorNo.value : this.colorNo,
        isDeleted: isDeleted ?? this.isDeleted,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  PurchaseLineRow copyWithCompanion(PurchaseLinesCompanion data) {
    return PurchaseLineRow(
      id: data.id.present ? data.id.value : this.id,
      orderId: data.orderId.present ? data.orderId.value : this.orderId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      name: data.name.present ? data.name.value : this.name,
      unit: data.unit.present ? data.unit.value : this.unit,
      qty: data.qty.present ? data.qty.value : this.qty,
      note: data.note.present ? data.note.value : this.note,
      memo: data.memo.present ? data.memo.value : this.memo,
      colorNo: data.colorNo.present ? data.colorNo.value : this.colorNo,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PurchaseLineRow(')
          ..write('id: $id, ')
          ..write('orderId: $orderId, ')
          ..write('itemId: $itemId, ')
          ..write('name: $name, ')
          ..write('unit: $unit, ')
          ..write('qty: $qty, ')
          ..write('note: $note, ')
          ..write('memo: $memo, ')
          ..write('colorNo: $colorNo, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, orderId, itemId, name, unit, qty, note,
      memo, colorNo, isDeleted, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PurchaseLineRow &&
          other.id == this.id &&
          other.orderId == this.orderId &&
          other.itemId == this.itemId &&
          other.name == this.name &&
          other.unit == this.unit &&
          other.qty == this.qty &&
          other.note == this.note &&
          other.memo == this.memo &&
          other.colorNo == this.colorNo &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt);
}

class PurchaseLinesCompanion extends UpdateCompanion<PurchaseLineRow> {
  final Value<String> id;
  final Value<String> orderId;
  final Value<String> itemId;
  final Value<String> name;
  final Value<String> unit;
  final Value<double> qty;
  final Value<String?> note;
  final Value<String?> memo;
  final Value<String?> colorNo;
  final Value<bool> isDeleted;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const PurchaseLinesCompanion({
    this.id = const Value.absent(),
    this.orderId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.name = const Value.absent(),
    this.unit = const Value.absent(),
    this.qty = const Value.absent(),
    this.note = const Value.absent(),
    this.memo = const Value.absent(),
    this.colorNo = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PurchaseLinesCompanion.insert({
    required String id,
    required String orderId,
    required String itemId,
    required String name,
    required String unit,
    required double qty,
    this.note = const Value.absent(),
    this.memo = const Value.absent(),
    this.colorNo = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        orderId = Value(orderId),
        itemId = Value(itemId),
        name = Value(name),
        unit = Value(unit),
        qty = Value(qty);
  static Insertable<PurchaseLineRow> custom({
    Expression<String>? id,
    Expression<String>? orderId,
    Expression<String>? itemId,
    Expression<String>? name,
    Expression<String>? unit,
    Expression<double>? qty,
    Expression<String>? note,
    Expression<String>? memo,
    Expression<String>? colorNo,
    Expression<bool>? isDeleted,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (orderId != null) 'order_id': orderId,
      if (itemId != null) 'item_id': itemId,
      if (name != null) 'name': name,
      if (unit != null) 'unit': unit,
      if (qty != null) 'qty': qty,
      if (note != null) 'note': note,
      if (memo != null) 'memo': memo,
      if (colorNo != null) 'color_no': colorNo,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PurchaseLinesCompanion copyWith(
      {Value<String>? id,
      Value<String>? orderId,
      Value<String>? itemId,
      Value<String>? name,
      Value<String>? unit,
      Value<double>? qty,
      Value<String?>? note,
      Value<String?>? memo,
      Value<String?>? colorNo,
      Value<bool>? isDeleted,
      Value<String?>? deletedAt,
      Value<int>? rowid}) {
    return PurchaseLinesCompanion(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      qty: qty ?? this.qty,
      note: note ?? this.note,
      memo: memo ?? this.memo,
      colorNo: colorNo ?? this.colorNo,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (orderId.present) {
      map['order_id'] = Variable<String>(orderId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (qty.present) {
      map['qty'] = Variable<double>(qty.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (memo.present) {
      map['memo'] = Variable<String>(memo.value);
    }
    if (colorNo.present) {
      map['color_no'] = Variable<String>(colorNo.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PurchaseLinesCompanion(')
          ..write('id: $id, ')
          ..write('orderId: $orderId, ')
          ..write('itemId: $itemId, ')
          ..write('name: $name, ')
          ..write('unit: $unit, ')
          ..write('qty: $qty, ')
          ..write('note: $note, ')
          ..write('memo: $memo, ')
          ..write('colorNo: $colorNo, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SuppliersTable extends Suppliers
    with TableInfo<$SuppliersTable, SupplierRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SuppliersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contactNameMeta =
      const VerificationMeta('contactName');
  @override
  late final GeneratedColumn<String> contactName = GeneratedColumn<String>(
      'contact_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
      'phone', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _addrMeta = const VerificationMeta('addr');
  @override
  late final GeneratedColumn<String> addr = GeneratedColumn<String>(
      'addr', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _memoMeta = const VerificationMeta('memo');
  @override
  late final GeneratedColumn<String> memo = GeneratedColumn<String>(
      'memo', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
      'created_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        contactName,
        phone,
        email,
        addr,
        memo,
        isActive,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'suppliers';
  @override
  VerificationContext validateIntegrity(Insertable<SupplierRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('contact_name')) {
      context.handle(
          _contactNameMeta,
          contactName.isAcceptableOrUnknown(
              data['contact_name']!, _contactNameMeta));
    }
    if (data.containsKey('phone')) {
      context.handle(
          _phoneMeta, phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta));
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    }
    if (data.containsKey('addr')) {
      context.handle(
          _addrMeta, addr.isAcceptableOrUnknown(data['addr']!, _addrMeta));
    }
    if (data.containsKey('memo')) {
      context.handle(
          _memoMeta, memo.isAcceptableOrUnknown(data['memo']!, _memoMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SupplierRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SupplierRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      contactName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}contact_name']),
      phone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}phone']),
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email']),
      addr: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}addr']),
      memo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}memo']),
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $SuppliersTable createAlias(String alias) {
    return $SuppliersTable(attachedDatabase, alias);
  }
}

class SupplierRow extends DataClass implements Insertable<SupplierRow> {
  final String id;
  final String name;
  final String? contactName;
  final String? phone;
  final String? email;
  final String? addr;
  final String? memo;
  final bool isActive;
  final String createdAt;
  final String updatedAt;
  const SupplierRow(
      {required this.id,
      required this.name,
      this.contactName,
      this.phone,
      this.email,
      this.addr,
      this.memo,
      required this.isActive,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || contactName != null) {
      map['contact_name'] = Variable<String>(contactName);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || addr != null) {
      map['addr'] = Variable<String>(addr);
    }
    if (!nullToAbsent || memo != null) {
      map['memo'] = Variable<String>(memo);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  SuppliersCompanion toCompanion(bool nullToAbsent) {
    return SuppliersCompanion(
      id: Value(id),
      name: Value(name),
      contactName: contactName == null && nullToAbsent
          ? const Value.absent()
          : Value(contactName),
      phone:
          phone == null && nullToAbsent ? const Value.absent() : Value(phone),
      email:
          email == null && nullToAbsent ? const Value.absent() : Value(email),
      addr: addr == null && nullToAbsent ? const Value.absent() : Value(addr),
      memo: memo == null && nullToAbsent ? const Value.absent() : Value(memo),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SupplierRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SupplierRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      contactName: serializer.fromJson<String?>(json['contactName']),
      phone: serializer.fromJson<String?>(json['phone']),
      email: serializer.fromJson<String?>(json['email']),
      addr: serializer.fromJson<String?>(json['addr']),
      memo: serializer.fromJson<String?>(json['memo']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'contactName': serializer.toJson<String?>(contactName),
      'phone': serializer.toJson<String?>(phone),
      'email': serializer.toJson<String?>(email),
      'addr': serializer.toJson<String?>(addr),
      'memo': serializer.toJson<String?>(memo),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  SupplierRow copyWith(
          {String? id,
          String? name,
          Value<String?> contactName = const Value.absent(),
          Value<String?> phone = const Value.absent(),
          Value<String?> email = const Value.absent(),
          Value<String?> addr = const Value.absent(),
          Value<String?> memo = const Value.absent(),
          bool? isActive,
          String? createdAt,
          String? updatedAt}) =>
      SupplierRow(
        id: id ?? this.id,
        name: name ?? this.name,
        contactName: contactName.present ? contactName.value : this.contactName,
        phone: phone.present ? phone.value : this.phone,
        email: email.present ? email.value : this.email,
        addr: addr.present ? addr.value : this.addr,
        memo: memo.present ? memo.value : this.memo,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  SupplierRow copyWithCompanion(SuppliersCompanion data) {
    return SupplierRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      contactName:
          data.contactName.present ? data.contactName.value : this.contactName,
      phone: data.phone.present ? data.phone.value : this.phone,
      email: data.email.present ? data.email.value : this.email,
      addr: data.addr.present ? data.addr.value : this.addr,
      memo: data.memo.present ? data.memo.value : this.memo,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SupplierRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('contactName: $contactName, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('addr: $addr, ')
          ..write('memo: $memo, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, contactName, phone, email, addr,
      memo, isActive, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SupplierRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.contactName == this.contactName &&
          other.phone == this.phone &&
          other.email == this.email &&
          other.addr == this.addr &&
          other.memo == this.memo &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SuppliersCompanion extends UpdateCompanion<SupplierRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> contactName;
  final Value<String?> phone;
  final Value<String?> email;
  final Value<String?> addr;
  final Value<String?> memo;
  final Value<bool> isActive;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const SuppliersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.contactName = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.addr = const Value.absent(),
    this.memo = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SuppliersCompanion.insert({
    required String id,
    required String name,
    this.contactName = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.addr = const Value.absent(),
    this.memo = const Value.absent(),
    this.isActive = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<SupplierRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? contactName,
    Expression<String>? phone,
    Expression<String>? email,
    Expression<String>? addr,
    Expression<String>? memo,
    Expression<bool>? isActive,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (contactName != null) 'contact_name': contactName,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (addr != null) 'addr': addr,
      if (memo != null) 'memo': memo,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SuppliersCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String?>? contactName,
      Value<String?>? phone,
      Value<String?>? email,
      Value<String?>? addr,
      Value<String?>? memo,
      Value<bool>? isActive,
      Value<String>? createdAt,
      Value<String>? updatedAt,
      Value<int>? rowid}) {
    return SuppliersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      contactName: contactName ?? this.contactName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      addr: addr ?? this.addr,
      memo: memo ?? this.memo,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (contactName.present) {
      map['contact_name'] = Variable<String>(contactName.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (addr.present) {
      map['addr'] = Variable<String>(addr.value);
    }
    if (memo.present) {
      map['memo'] = Variable<String>(memo.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SuppliersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('contactName: $contactName, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('addr: $addr, ')
          ..write('memo: $memo, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LotsTable extends Lots with TableInfo<$LotsTable, LotRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
      'item_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES items (id) ON DELETE CASCADE'));
  static const VerificationMeta _lotNoMeta = const VerificationMeta('lotNo');
  @override
  late final GeneratedColumn<String> lotNo = GeneratedColumn<String>(
      'lot_no', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _receivedQtyRollMeta =
      const VerificationMeta('receivedQtyRoll');
  @override
  late final GeneratedColumn<double> receivedQtyRoll = GeneratedColumn<double>(
      'received_qty_roll', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _measuredLengthMMeta =
      const VerificationMeta('measuredLengthM');
  @override
  late final GeneratedColumn<double> measuredLengthM = GeneratedColumn<double>(
      'measured_length_m', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _usableQtyMMeta =
      const VerificationMeta('usableQtyM');
  @override
  late final GeneratedColumn<double> usableQtyM = GeneratedColumn<double>(
      'usable_qty_m', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('active'));
  static const VerificationMeta _receivedAtMeta =
      const VerificationMeta('receivedAt');
  @override
  late final GeneratedColumn<String> receivedAt = GeneratedColumn<String>(
      'received_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        itemId,
        lotNo,
        receivedQtyRoll,
        measuredLengthM,
        usableQtyM,
        status,
        receivedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lots';
  @override
  VerificationContext validateIntegrity(Insertable<LotRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('lot_no')) {
      context.handle(
          _lotNoMeta, lotNo.isAcceptableOrUnknown(data['lot_no']!, _lotNoMeta));
    } else if (isInserting) {
      context.missing(_lotNoMeta);
    }
    if (data.containsKey('received_qty_roll')) {
      context.handle(
          _receivedQtyRollMeta,
          receivedQtyRoll.isAcceptableOrUnknown(
              data['received_qty_roll']!, _receivedQtyRollMeta));
    } else if (isInserting) {
      context.missing(_receivedQtyRollMeta);
    }
    if (data.containsKey('measured_length_m')) {
      context.handle(
          _measuredLengthMMeta,
          measuredLengthM.isAcceptableOrUnknown(
              data['measured_length_m']!, _measuredLengthMMeta));
    } else if (isInserting) {
      context.missing(_measuredLengthMMeta);
    }
    if (data.containsKey('usable_qty_m')) {
      context.handle(
          _usableQtyMMeta,
          usableQtyM.isAcceptableOrUnknown(
              data['usable_qty_m']!, _usableQtyMMeta));
    } else if (isInserting) {
      context.missing(_usableQtyMMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('received_at')) {
      context.handle(
          _receivedAtMeta,
          receivedAt.isAcceptableOrUnknown(
              data['received_at']!, _receivedAtMeta));
    } else if (isInserting) {
      context.missing(_receivedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LotRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LotRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      lotNo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}lot_no'])!,
      receivedQtyRoll: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}received_qty_roll'])!,
      measuredLengthM: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}measured_length_m'])!,
      usableQtyM: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}usable_qty_m'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      receivedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}received_at'])!,
    );
  }

  @override
  $LotsTable createAlias(String alias) {
    return $LotsTable(attachedDatabase, alias);
  }
}

class LotRow extends DataClass implements Insertable<LotRow> {
  final String id;
  final String itemId;
  final String lotNo;
  final double receivedQtyRoll;
  final double measuredLengthM;
  final double usableQtyM;
  final String status;
  final String receivedAt;
  const LotRow(
      {required this.id,
      required this.itemId,
      required this.lotNo,
      required this.receivedQtyRoll,
      required this.measuredLengthM,
      required this.usableQtyM,
      required this.status,
      required this.receivedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['item_id'] = Variable<String>(itemId);
    map['lot_no'] = Variable<String>(lotNo);
    map['received_qty_roll'] = Variable<double>(receivedQtyRoll);
    map['measured_length_m'] = Variable<double>(measuredLengthM);
    map['usable_qty_m'] = Variable<double>(usableQtyM);
    map['status'] = Variable<String>(status);
    map['received_at'] = Variable<String>(receivedAt);
    return map;
  }

  LotsCompanion toCompanion(bool nullToAbsent) {
    return LotsCompanion(
      id: Value(id),
      itemId: Value(itemId),
      lotNo: Value(lotNo),
      receivedQtyRoll: Value(receivedQtyRoll),
      measuredLengthM: Value(measuredLengthM),
      usableQtyM: Value(usableQtyM),
      status: Value(status),
      receivedAt: Value(receivedAt),
    );
  }

  factory LotRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LotRow(
      id: serializer.fromJson<String>(json['id']),
      itemId: serializer.fromJson<String>(json['itemId']),
      lotNo: serializer.fromJson<String>(json['lotNo']),
      receivedQtyRoll: serializer.fromJson<double>(json['receivedQtyRoll']),
      measuredLengthM: serializer.fromJson<double>(json['measuredLengthM']),
      usableQtyM: serializer.fromJson<double>(json['usableQtyM']),
      status: serializer.fromJson<String>(json['status']),
      receivedAt: serializer.fromJson<String>(json['receivedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'itemId': serializer.toJson<String>(itemId),
      'lotNo': serializer.toJson<String>(lotNo),
      'receivedQtyRoll': serializer.toJson<double>(receivedQtyRoll),
      'measuredLengthM': serializer.toJson<double>(measuredLengthM),
      'usableQtyM': serializer.toJson<double>(usableQtyM),
      'status': serializer.toJson<String>(status),
      'receivedAt': serializer.toJson<String>(receivedAt),
    };
  }

  LotRow copyWith(
          {String? id,
          String? itemId,
          String? lotNo,
          double? receivedQtyRoll,
          double? measuredLengthM,
          double? usableQtyM,
          String? status,
          String? receivedAt}) =>
      LotRow(
        id: id ?? this.id,
        itemId: itemId ?? this.itemId,
        lotNo: lotNo ?? this.lotNo,
        receivedQtyRoll: receivedQtyRoll ?? this.receivedQtyRoll,
        measuredLengthM: measuredLengthM ?? this.measuredLengthM,
        usableQtyM: usableQtyM ?? this.usableQtyM,
        status: status ?? this.status,
        receivedAt: receivedAt ?? this.receivedAt,
      );
  LotRow copyWithCompanion(LotsCompanion data) {
    return LotRow(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      lotNo: data.lotNo.present ? data.lotNo.value : this.lotNo,
      receivedQtyRoll: data.receivedQtyRoll.present
          ? data.receivedQtyRoll.value
          : this.receivedQtyRoll,
      measuredLengthM: data.measuredLengthM.present
          ? data.measuredLengthM.value
          : this.measuredLengthM,
      usableQtyM:
          data.usableQtyM.present ? data.usableQtyM.value : this.usableQtyM,
      status: data.status.present ? data.status.value : this.status,
      receivedAt:
          data.receivedAt.present ? data.receivedAt.value : this.receivedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LotRow(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('lotNo: $lotNo, ')
          ..write('receivedQtyRoll: $receivedQtyRoll, ')
          ..write('measuredLengthM: $measuredLengthM, ')
          ..write('usableQtyM: $usableQtyM, ')
          ..write('status: $status, ')
          ..write('receivedAt: $receivedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, itemId, lotNo, receivedQtyRoll,
      measuredLengthM, usableQtyM, status, receivedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LotRow &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.lotNo == this.lotNo &&
          other.receivedQtyRoll == this.receivedQtyRoll &&
          other.measuredLengthM == this.measuredLengthM &&
          other.usableQtyM == this.usableQtyM &&
          other.status == this.status &&
          other.receivedAt == this.receivedAt);
}

class LotsCompanion extends UpdateCompanion<LotRow> {
  final Value<String> id;
  final Value<String> itemId;
  final Value<String> lotNo;
  final Value<double> receivedQtyRoll;
  final Value<double> measuredLengthM;
  final Value<double> usableQtyM;
  final Value<String> status;
  final Value<String> receivedAt;
  final Value<int> rowid;
  const LotsCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.lotNo = const Value.absent(),
    this.receivedQtyRoll = const Value.absent(),
    this.measuredLengthM = const Value.absent(),
    this.usableQtyM = const Value.absent(),
    this.status = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LotsCompanion.insert({
    required String id,
    required String itemId,
    required String lotNo,
    required double receivedQtyRoll,
    required double measuredLengthM,
    required double usableQtyM,
    this.status = const Value.absent(),
    required String receivedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        itemId = Value(itemId),
        lotNo = Value(lotNo),
        receivedQtyRoll = Value(receivedQtyRoll),
        measuredLengthM = Value(measuredLengthM),
        usableQtyM = Value(usableQtyM),
        receivedAt = Value(receivedAt);
  static Insertable<LotRow> custom({
    Expression<String>? id,
    Expression<String>? itemId,
    Expression<String>? lotNo,
    Expression<double>? receivedQtyRoll,
    Expression<double>? measuredLengthM,
    Expression<double>? usableQtyM,
    Expression<String>? status,
    Expression<String>? receivedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (lotNo != null) 'lot_no': lotNo,
      if (receivedQtyRoll != null) 'received_qty_roll': receivedQtyRoll,
      if (measuredLengthM != null) 'measured_length_m': measuredLengthM,
      if (usableQtyM != null) 'usable_qty_m': usableQtyM,
      if (status != null) 'status': status,
      if (receivedAt != null) 'received_at': receivedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LotsCompanion copyWith(
      {Value<String>? id,
      Value<String>? itemId,
      Value<String>? lotNo,
      Value<double>? receivedQtyRoll,
      Value<double>? measuredLengthM,
      Value<double>? usableQtyM,
      Value<String>? status,
      Value<String>? receivedAt,
      Value<int>? rowid}) {
    return LotsCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      lotNo: lotNo ?? this.lotNo,
      receivedQtyRoll: receivedQtyRoll ?? this.receivedQtyRoll,
      measuredLengthM: measuredLengthM ?? this.measuredLengthM,
      usableQtyM: usableQtyM ?? this.usableQtyM,
      status: status ?? this.status,
      receivedAt: receivedAt ?? this.receivedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (lotNo.present) {
      map['lot_no'] = Variable<String>(lotNo.value);
    }
    if (receivedQtyRoll.present) {
      map['received_qty_roll'] = Variable<double>(receivedQtyRoll.value);
    }
    if (measuredLengthM.present) {
      map['measured_length_m'] = Variable<double>(measuredLengthM.value);
    }
    if (usableQtyM.present) {
      map['usable_qty_m'] = Variable<double>(usableQtyM.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<String>(receivedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LotsCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('lotNo: $lotNo, ')
          ..write('receivedQtyRoll: $receivedQtyRoll, ')
          ..write('measuredLengthM: $measuredLengthM, ')
          ..write('usableQtyM: $usableQtyM, ')
          ..write('status: $status, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QuickActionOrdersTable extends QuickActionOrders
    with TableInfo<$QuickActionOrdersTable, QuickActionOrder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuickActionOrdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
      'action', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _orderIndexMeta =
      const VerificationMeta('orderIndex');
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
      'order_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [action, orderIndex];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quick_action_orders';
  @override
  VerificationContext validateIntegrity(Insertable<QuickActionOrder> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('action')) {
      context.handle(_actionMeta,
          action.isAcceptableOrUnknown(data['action']!, _actionMeta));
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
          _orderIndexMeta,
          orderIndex.isAcceptableOrUnknown(
              data['order_index']!, _orderIndexMeta));
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {action};
  @override
  QuickActionOrder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuickActionOrder(
      action: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}action'])!,
      orderIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}order_index'])!,
    );
  }

  @override
  $QuickActionOrdersTable createAlias(String alias) {
    return $QuickActionOrdersTable(attachedDatabase, alias);
  }
}

class QuickActionOrder extends DataClass
    implements Insertable<QuickActionOrder> {
  final String action;
  final int orderIndex;
  const QuickActionOrder({required this.action, required this.orderIndex});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['action'] = Variable<String>(action);
    map['order_index'] = Variable<int>(orderIndex);
    return map;
  }

  QuickActionOrdersCompanion toCompanion(bool nullToAbsent) {
    return QuickActionOrdersCompanion(
      action: Value(action),
      orderIndex: Value(orderIndex),
    );
  }

  factory QuickActionOrder.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuickActionOrder(
      action: serializer.fromJson<String>(json['action']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'action': serializer.toJson<String>(action),
      'orderIndex': serializer.toJson<int>(orderIndex),
    };
  }

  QuickActionOrder copyWith({String? action, int? orderIndex}) =>
      QuickActionOrder(
        action: action ?? this.action,
        orderIndex: orderIndex ?? this.orderIndex,
      );
  QuickActionOrder copyWithCompanion(QuickActionOrdersCompanion data) {
    return QuickActionOrder(
      action: data.action.present ? data.action.value : this.action,
      orderIndex:
          data.orderIndex.present ? data.orderIndex.value : this.orderIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuickActionOrder(')
          ..write('action: $action, ')
          ..write('orderIndex: $orderIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(action, orderIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuickActionOrder &&
          other.action == this.action &&
          other.orderIndex == this.orderIndex);
}

class QuickActionOrdersCompanion extends UpdateCompanion<QuickActionOrder> {
  final Value<String> action;
  final Value<int> orderIndex;
  final Value<int> rowid;
  const QuickActionOrdersCompanion({
    this.action = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QuickActionOrdersCompanion.insert({
    required String action,
    required int orderIndex,
    this.rowid = const Value.absent(),
  })  : action = Value(action),
        orderIndex = Value(orderIndex);
  static Insertable<QuickActionOrder> custom({
    Expression<String>? action,
    Expression<int>? orderIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (action != null) 'action': action,
      if (orderIndex != null) 'order_index': orderIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QuickActionOrdersCompanion copyWith(
      {Value<String>? action, Value<int>? orderIndex, Value<int>? rowid}) {
    return QuickActionOrdersCompanion(
      action: action ?? this.action,
      orderIndex: orderIndex ?? this.orderIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuickActionOrdersCompanion(')
          ..write('action: $action, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ItemsTable items = $ItemsTable(this);
  late final $FoldersTable folders = $FoldersTable(this);
  late final $ItemPathsTable itemPaths = $ItemPathsTable(this);
  late final $TxnsTable txns = $TxnsTable(this);
  late final $BomRowsTable bomRows = $BomRowsTable(this);
  late final $OrdersTable orders = $OrdersTable(this);
  late final $OrderLinesTable orderLines = $OrderLinesTable(this);
  late final $WorksTable works = $WorksTable(this);
  late final $PurchaseOrdersTable purchaseOrders = $PurchaseOrdersTable(this);
  late final $PurchaseLinesTable purchaseLines = $PurchaseLinesTable(this);
  late final $SuppliersTable suppliers = $SuppliersTable(this);
  late final $LotsTable lots = $LotsTable(this);
  late final $QuickActionOrdersTable quickActionOrders =
      $QuickActionOrdersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        items,
        folders,
        itemPaths,
        txns,
        bomRows,
        orders,
        orderLines,
        works,
        purchaseOrders,
        purchaseLines,
        suppliers,
        lots,
        quickActionOrders
      ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('folders',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('folders', kind: UpdateKind.update),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('items',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('item_paths', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('folders',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('item_paths', kind: UpdateKind.update),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('folders',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('item_paths', kind: UpdateKind.update),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('folders',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('item_paths', kind: UpdateKind.update),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('items',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('txns', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('items',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('bom_rows', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('items',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('bom_rows', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('orders',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('order_lines', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('orders',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('works', kind: UpdateKind.update),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('purchase_orders',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('purchase_lines', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('items',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('lots', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$ItemsTableCreateCompanionBuilder = ItemsCompanion Function({
  required String id,
  required String name,
  Value<String?> displayName,
  required String sku,
  required String unit,
  Value<String> searchNormalized,
  Value<String> searchInitials,
  Value<String> searchFullNormalized,
  required String folder,
  Value<String?> subfolder,
  Value<String?> subsubfolder,
  Value<int> minQty,
  Value<int> qty,
  Value<String?> kind,
  Value<String?> attrsJson,
  Value<String> unitIn,
  Value<String> unitOut,
  Value<double> conversionRate,
  Value<String> conversionMode,
  Value<String?> stockHintsJson,
  Value<String?> supplierName,
  Value<bool> isFavorite,
  Value<bool> isDeleted,
  Value<String?> deletedAt,
  Value<int> rowid,
});
typedef $$ItemsTableUpdateCompanionBuilder = ItemsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> displayName,
  Value<String> sku,
  Value<String> unit,
  Value<String> searchNormalized,
  Value<String> searchInitials,
  Value<String> searchFullNormalized,
  Value<String> folder,
  Value<String?> subfolder,
  Value<String?> subsubfolder,
  Value<int> minQty,
  Value<int> qty,
  Value<String?> kind,
  Value<String?> attrsJson,
  Value<String> unitIn,
  Value<String> unitOut,
  Value<double> conversionRate,
  Value<String> conversionMode,
  Value<String?> stockHintsJson,
  Value<String?> supplierName,
  Value<bool> isFavorite,
  Value<bool> isDeleted,
  Value<String?> deletedAt,
  Value<int> rowid,
});

final class $$ItemsTableReferences
    extends BaseReferences<_$AppDatabase, $ItemsTable, ItemRow> {
  $$ItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ItemPathsTable, List<ItemPathRow>>
      _itemPathsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.itemPaths,
          aliasName: $_aliasNameGenerator(db.items.id, db.itemPaths.itemId));

  $$ItemPathsTableProcessedTableManager get itemPathsRefs {
    final manager = $$ItemPathsTableTableManager($_db, $_db.itemPaths)
        .filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_itemPathsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$TxnsTable, List<TxnRow>> _txnsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.txns,
          aliasName: $_aliasNameGenerator(db.items.id, db.txns.itemId));

  $$TxnsTableProcessedTableManager get txnsRefs {
    final manager = $$TxnsTableTableManager($_db, $_db.txns)
        .filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_txnsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$OrderLinesTable, List<OrderLineRow>>
      _orderLinesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.orderLines,
          aliasName: $_aliasNameGenerator(db.items.id, db.orderLines.itemId));

  $$OrderLinesTableProcessedTableManager get orderLinesRefs {
    final manager = $$OrderLinesTableTableManager($_db, $_db.orderLines)
        .filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_orderLinesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$WorksTable, List<WorkRow>> _worksRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.works,
          aliasName: $_aliasNameGenerator(db.items.id, db.works.itemId));

  $$WorksTableProcessedTableManager get worksRefs {
    final manager = $$WorksTableTableManager($_db, $_db.works)
        .filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_worksRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$PurchaseLinesTable, List<PurchaseLineRow>>
      _purchaseLinesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.purchaseLines,
              aliasName:
                  $_aliasNameGenerator(db.items.id, db.purchaseLines.itemId));

  $$PurchaseLinesTableProcessedTableManager get purchaseLinesRefs {
    final manager = $$PurchaseLinesTableTableManager($_db, $_db.purchaseLines)
        .filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_purchaseLinesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$LotsTable, List<LotRow>> _lotsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.lots,
          aliasName: $_aliasNameGenerator(db.items.id, db.lots.itemId));

  $$LotsTableProcessedTableManager get lotsRefs {
    final manager = $$LotsTableTableManager($_db, $_db.lots)
        .filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_lotsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ItemsTableFilterComposer extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sku => $composableBuilder(
      column: $table.sku, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get searchNormalized => $composableBuilder(
      column: $table.searchNormalized,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get searchInitials => $composableBuilder(
      column: $table.searchInitials,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get searchFullNormalized => $composableBuilder(
      column: $table.searchFullNormalized,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get folder => $composableBuilder(
      column: $table.folder, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subfolder => $composableBuilder(
      column: $table.subfolder, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subsubfolder => $composableBuilder(
      column: $table.subsubfolder, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get minQty => $composableBuilder(
      column: $table.minQty, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get qty => $composableBuilder(
      column: $table.qty, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get attrsJson => $composableBuilder(
      column: $table.attrsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get unitIn => $composableBuilder(
      column: $table.unitIn, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get unitOut => $composableBuilder(
      column: $table.unitOut, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get conversionRate => $composableBuilder(
      column: $table.conversionRate,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get conversionMode => $composableBuilder(
      column: $table.conversionMode,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stockHintsJson => $composableBuilder(
      column: $table.stockHintsJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get supplierName => $composableBuilder(
      column: $table.supplierName, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> itemPathsRefs(
      Expression<bool> Function($$ItemPathsTableFilterComposer f) f) {
    final $$ItemPathsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.itemPaths,
        getReferencedColumn: (t) => t.itemId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItemPathsTableFilterComposer(
              $db: $db,
              $table: $db.itemPaths,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> txnsRefs(
      Expression<bool> Function($$TxnsTableFilterComposer f) f) {
    final $$TxnsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.txns,
        getReferencedColumn: (t) => t.itemId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TxnsTableFilterComposer(
              $db: $db,
              $table: $db.txns,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> orderLinesRefs(
      Expression<bool> Function($$OrderLinesTableFilterComposer f) f) {
    final $$OrderLinesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.orderLines,
        getReferencedColumn: (t) => t.itemId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OrderLinesTableFilterComposer(
              $db: $db,
              $table: $db.orderLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> worksRefs(
      Expression<bool> Function($$WorksTableFilterComposer f) f) {
    final $$WorksTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.works,
        getReferencedColumn: (t) => t.itemId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WorksTableFilterComposer(
              $db: $db,
              $table: $db.works,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> purchaseLinesRefs(
      Expression<bool> Function($$PurchaseLinesTableFilterComposer f) f) {
    final $$PurchaseLinesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.purchaseLines,
        getReferencedColumn: (t) => t.itemId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PurchaseLinesTableFilterComposer(
              $db: $db,
              $table: $db.purchaseLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> lotsRefs(
      Expression<bool> Function($$LotsTableFilterComposer f) f) {
    final $$LotsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.lots,
        getReferencedColumn: (t) => t.itemId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$LotsTableFilterComposer(
              $db: $db,
              $table: $db.lots,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sku => $composableBuilder(
      column: $table.sku, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get searchNormalized => $composableBuilder(
      column: $table.searchNormalized,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get searchInitials => $composableBuilder(
      column: $table.searchInitials,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get searchFullNormalized => $composableBuilder(
      column: $table.searchFullNormalized,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get folder => $composableBuilder(
      column: $table.folder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subfolder => $composableBuilder(
      column: $table.subfolder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subsubfolder => $composableBuilder(
      column: $table.subsubfolder,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get minQty => $composableBuilder(
      column: $table.minQty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get qty => $composableBuilder(
      column: $table.qty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get attrsJson => $composableBuilder(
      column: $table.attrsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get unitIn => $composableBuilder(
      column: $table.unitIn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get unitOut => $composableBuilder(
      column: $table.unitOut, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get conversionRate => $composableBuilder(
      column: $table.conversionRate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get conversionMode => $composableBuilder(
      column: $table.conversionMode,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stockHintsJson => $composableBuilder(
      column: $table.stockHintsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get supplierName => $composableBuilder(
      column: $table.supplierName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$ItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => column);

  GeneratedColumn<String> get sku =>
      $composableBuilder(column: $table.sku, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get searchNormalized => $composableBuilder(
      column: $table.searchNormalized, builder: (column) => column);

  GeneratedColumn<String> get searchInitials => $composableBuilder(
      column: $table.searchInitials, builder: (column) => column);

  GeneratedColumn<String> get searchFullNormalized => $composableBuilder(
      column: $table.searchFullNormalized, builder: (column) => column);

  GeneratedColumn<String> get folder =>
      $composableBuilder(column: $table.folder, builder: (column) => column);

  GeneratedColumn<String> get subfolder =>
      $composableBuilder(column: $table.subfolder, builder: (column) => column);

  GeneratedColumn<String> get subsubfolder => $composableBuilder(
      column: $table.subsubfolder, builder: (column) => column);

  GeneratedColumn<int> get minQty =>
      $composableBuilder(column: $table.minQty, builder: (column) => column);

  GeneratedColumn<int> get qty =>
      $composableBuilder(column: $table.qty, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get attrsJson =>
      $composableBuilder(column: $table.attrsJson, builder: (column) => column);

  GeneratedColumn<String> get unitIn =>
      $composableBuilder(column: $table.unitIn, builder: (column) => column);

  GeneratedColumn<String> get unitOut =>
      $composableBuilder(column: $table.unitOut, builder: (column) => column);

  GeneratedColumn<double> get conversionRate => $composableBuilder(
      column: $table.conversionRate, builder: (column) => column);

  GeneratedColumn<String> get conversionMode => $composableBuilder(
      column: $table.conversionMode, builder: (column) => column);

  GeneratedColumn<String> get stockHintsJson => $composableBuilder(
      column: $table.stockHintsJson, builder: (column) => column);

  GeneratedColumn<String> get supplierName => $composableBuilder(
      column: $table.supplierName, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> itemPathsRefs<T extends Object>(
      Expression<T> Function($$ItemPathsTableAnnotationComposer a) f) {
    final $$ItemPathsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.itemPaths,
        getReferencedColumn: (t) => t.itemId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItemPathsTableAnnotationComposer(
              $db: $db,
              $table: $db.itemPaths,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> txnsRefs<T extends Object>(
      Expression<T> Function($$TxnsTableAnnotationComposer a) f) {
    final $$TxnsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.txns,
        getReferencedColumn: (t) => t.itemId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TxnsTableAnnotationComposer(
              $db: $db,
              $table: $db.txns,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> orderLinesRefs<T extends Object>(
      Expression<T> Function($$OrderLinesTableAnnotationComposer a) f) {
    final $$OrderLinesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.orderLines,
        getReferencedColumn: (t) => t.itemId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OrderLinesTableAnnotationComposer(
              $db: $db,
              $table: $db.orderLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> worksRefs<T extends Object>(
      Expression<T> Function($$WorksTableAnnotationComposer a) f) {
    final $$WorksTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.works,
        getReferencedColumn: (t) => t.itemId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WorksTableAnnotationComposer(
              $db: $db,
              $table: $db.works,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> purchaseLinesRefs<T extends Object>(
      Expression<T> Function($$PurchaseLinesTableAnnotationComposer a) f) {
    final $$PurchaseLinesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.purchaseLines,
        getReferencedColumn: (t) => t.itemId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PurchaseLinesTableAnnotationComposer(
              $db: $db,
              $table: $db.purchaseLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> lotsRefs<T extends Object>(
      Expression<T> Function($$LotsTableAnnotationComposer a) f) {
    final $$LotsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.lots,
        getReferencedColumn: (t) => t.itemId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$LotsTableAnnotationComposer(
              $db: $db,
              $table: $db.lots,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ItemsTable,
    ItemRow,
    $$ItemsTableFilterComposer,
    $$ItemsTableOrderingComposer,
    $$ItemsTableAnnotationComposer,
    $$ItemsTableCreateCompanionBuilder,
    $$ItemsTableUpdateCompanionBuilder,
    (ItemRow, $$ItemsTableReferences),
    ItemRow,
    PrefetchHooks Function(
        {bool itemPathsRefs,
        bool txnsRefs,
        bool orderLinesRefs,
        bool worksRefs,
        bool purchaseLinesRefs,
        bool lotsRefs})> {
  $$ItemsTableTableManager(_$AppDatabase db, $ItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> displayName = const Value.absent(),
            Value<String> sku = const Value.absent(),
            Value<String> unit = const Value.absent(),
            Value<String> searchNormalized = const Value.absent(),
            Value<String> searchInitials = const Value.absent(),
            Value<String> searchFullNormalized = const Value.absent(),
            Value<String> folder = const Value.absent(),
            Value<String?> subfolder = const Value.absent(),
            Value<String?> subsubfolder = const Value.absent(),
            Value<int> minQty = const Value.absent(),
            Value<int> qty = const Value.absent(),
            Value<String?> kind = const Value.absent(),
            Value<String?> attrsJson = const Value.absent(),
            Value<String> unitIn = const Value.absent(),
            Value<String> unitOut = const Value.absent(),
            Value<double> conversionRate = const Value.absent(),
            Value<String> conversionMode = const Value.absent(),
            Value<String?> stockHintsJson = const Value.absent(),
            Value<String?> supplierName = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<String?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ItemsCompanion(
            id: id,
            name: name,
            displayName: displayName,
            sku: sku,
            unit: unit,
            searchNormalized: searchNormalized,
            searchInitials: searchInitials,
            searchFullNormalized: searchFullNormalized,
            folder: folder,
            subfolder: subfolder,
            subsubfolder: subsubfolder,
            minQty: minQty,
            qty: qty,
            kind: kind,
            attrsJson: attrsJson,
            unitIn: unitIn,
            unitOut: unitOut,
            conversionRate: conversionRate,
            conversionMode: conversionMode,
            stockHintsJson: stockHintsJson,
            supplierName: supplierName,
            isFavorite: isFavorite,
            isDeleted: isDeleted,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String?> displayName = const Value.absent(),
            required String sku,
            required String unit,
            Value<String> searchNormalized = const Value.absent(),
            Value<String> searchInitials = const Value.absent(),
            Value<String> searchFullNormalized = const Value.absent(),
            required String folder,
            Value<String?> subfolder = const Value.absent(),
            Value<String?> subsubfolder = const Value.absent(),
            Value<int> minQty = const Value.absent(),
            Value<int> qty = const Value.absent(),
            Value<String?> kind = const Value.absent(),
            Value<String?> attrsJson = const Value.absent(),
            Value<String> unitIn = const Value.absent(),
            Value<String> unitOut = const Value.absent(),
            Value<double> conversionRate = const Value.absent(),
            Value<String> conversionMode = const Value.absent(),
            Value<String?> stockHintsJson = const Value.absent(),
            Value<String?> supplierName = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<String?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ItemsCompanion.insert(
            id: id,
            name: name,
            displayName: displayName,
            sku: sku,
            unit: unit,
            searchNormalized: searchNormalized,
            searchInitials: searchInitials,
            searchFullNormalized: searchFullNormalized,
            folder: folder,
            subfolder: subfolder,
            subsubfolder: subsubfolder,
            minQty: minQty,
            qty: qty,
            kind: kind,
            attrsJson: attrsJson,
            unitIn: unitIn,
            unitOut: unitOut,
            conversionRate: conversionRate,
            conversionMode: conversionMode,
            stockHintsJson: stockHintsJson,
            supplierName: supplierName,
            isFavorite: isFavorite,
            isDeleted: isDeleted,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$ItemsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {itemPathsRefs = false,
              txnsRefs = false,
              orderLinesRefs = false,
              worksRefs = false,
              purchaseLinesRefs = false,
              lotsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (itemPathsRefs) db.itemPaths,
                if (txnsRefs) db.txns,
                if (orderLinesRefs) db.orderLines,
                if (worksRefs) db.works,
                if (purchaseLinesRefs) db.purchaseLines,
                if (lotsRefs) db.lots
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (itemPathsRefs)
                    await $_getPrefetchedData<ItemRow, $ItemsTable,
                            ItemPathRow>(
                        currentTable: table,
                        referencedTable:
                            $$ItemsTableReferences._itemPathsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ItemsTableReferences(db, table, p0).itemPathsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.itemId == item.id),
                        typedResults: items),
                  if (txnsRefs)
                    await $_getPrefetchedData<ItemRow, $ItemsTable, TxnRow>(
                        currentTable: table,
                        referencedTable:
                            $$ItemsTableReferences._txnsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ItemsTableReferences(db, table, p0).txnsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.itemId == item.id),
                        typedResults: items),
                  if (orderLinesRefs)
                    await $_getPrefetchedData<ItemRow, $ItemsTable,
                            OrderLineRow>(
                        currentTable: table,
                        referencedTable:
                            $$ItemsTableReferences._orderLinesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ItemsTableReferences(db, table, p0)
                                .orderLinesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.itemId == item.id),
                        typedResults: items),
                  if (worksRefs)
                    await $_getPrefetchedData<ItemRow, $ItemsTable, WorkRow>(
                        currentTable: table,
                        referencedTable:
                            $$ItemsTableReferences._worksRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ItemsTableReferences(db, table, p0).worksRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.itemId == item.id),
                        typedResults: items),
                  if (purchaseLinesRefs)
                    await $_getPrefetchedData<ItemRow, $ItemsTable,
                            PurchaseLineRow>(
                        currentTable: table,
                        referencedTable:
                            $$ItemsTableReferences._purchaseLinesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ItemsTableReferences(db, table, p0)
                                .purchaseLinesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.itemId == item.id),
                        typedResults: items),
                  if (lotsRefs)
                    await $_getPrefetchedData<ItemRow, $ItemsTable, LotRow>(
                        currentTable: table,
                        referencedTable:
                            $$ItemsTableReferences._lotsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ItemsTableReferences(db, table, p0).lotsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.itemId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ItemsTable,
    ItemRow,
    $$ItemsTableFilterComposer,
    $$ItemsTableOrderingComposer,
    $$ItemsTableAnnotationComposer,
    $$ItemsTableCreateCompanionBuilder,
    $$ItemsTableUpdateCompanionBuilder,
    (ItemRow, $$ItemsTableReferences),
    ItemRow,
    PrefetchHooks Function(
        {bool itemPathsRefs,
        bool txnsRefs,
        bool orderLinesRefs,
        bool worksRefs,
        bool purchaseLinesRefs,
        bool lotsRefs})>;
typedef $$FoldersTableCreateCompanionBuilder = FoldersCompanion Function({
  required String id,
  required String name,
  Value<String?> parentId,
  required int depth,
  Value<int> order,
  Value<String> searchNormalized,
  Value<String> searchInitials,
  Value<int> rowid,
});
typedef $$FoldersTableUpdateCompanionBuilder = FoldersCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> parentId,
  Value<int> depth,
  Value<int> order,
  Value<String> searchNormalized,
  Value<String> searchInitials,
  Value<int> rowid,
});

final class $$FoldersTableReferences
    extends BaseReferences<_$AppDatabase, $FoldersTable, FolderRow> {
  $$FoldersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FoldersTable _parentIdTable(_$AppDatabase db) => db.folders
      .createAlias($_aliasNameGenerator(db.folders.parentId, db.folders.id));

  $$FoldersTableProcessedTableManager? get parentId {
    final $_column = $_itemColumn<String>('parent_id');
    if ($_column == null) return null;
    final manager = $$FoldersTableTableManager($_db, $_db.folders)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
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
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get depth => $composableBuilder(
      column: $table.depth, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get order => $composableBuilder(
      column: $table.order, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get searchNormalized => $composableBuilder(
      column: $table.searchNormalized,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get searchInitials => $composableBuilder(
      column: $table.searchInitials,
      builder: (column) => ColumnFilters(column));

  $$FoldersTableFilterComposer get parentId {
    final $$FoldersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parentId,
        referencedTable: $db.folders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FoldersTableFilterComposer(
              $db: $db,
              $table: $db.folders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
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
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get depth => $composableBuilder(
      column: $table.depth, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get order => $composableBuilder(
      column: $table.order, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get searchNormalized => $composableBuilder(
      column: $table.searchNormalized,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get searchInitials => $composableBuilder(
      column: $table.searchInitials,
      builder: (column) => ColumnOrderings(column));

  $$FoldersTableOrderingComposer get parentId {
    final $$FoldersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parentId,
        referencedTable: $db.folders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FoldersTableOrderingComposer(
              $db: $db,
              $table: $db.folders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
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

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get depth =>
      $composableBuilder(column: $table.depth, builder: (column) => column);

  GeneratedColumn<int> get order =>
      $composableBuilder(column: $table.order, builder: (column) => column);

  GeneratedColumn<String> get searchNormalized => $composableBuilder(
      column: $table.searchNormalized, builder: (column) => column);

  GeneratedColumn<String> get searchInitials => $composableBuilder(
      column: $table.searchInitials, builder: (column) => column);

  $$FoldersTableAnnotationComposer get parentId {
    final $$FoldersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parentId,
        referencedTable: $db.folders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FoldersTableAnnotationComposer(
              $db: $db,
              $table: $db.folders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FoldersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FoldersTable,
    FolderRow,
    $$FoldersTableFilterComposer,
    $$FoldersTableOrderingComposer,
    $$FoldersTableAnnotationComposer,
    $$FoldersTableCreateCompanionBuilder,
    $$FoldersTableUpdateCompanionBuilder,
    (FolderRow, $$FoldersTableReferences),
    FolderRow,
    PrefetchHooks Function({bool parentId})> {
  $$FoldersTableTableManager(_$AppDatabase db, $FoldersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> parentId = const Value.absent(),
            Value<int> depth = const Value.absent(),
            Value<int> order = const Value.absent(),
            Value<String> searchNormalized = const Value.absent(),
            Value<String> searchInitials = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FoldersCompanion(
            id: id,
            name: name,
            parentId: parentId,
            depth: depth,
            order: order,
            searchNormalized: searchNormalized,
            searchInitials: searchInitials,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String?> parentId = const Value.absent(),
            required int depth,
            Value<int> order = const Value.absent(),
            Value<String> searchNormalized = const Value.absent(),
            Value<String> searchInitials = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FoldersCompanion.insert(
            id: id,
            name: name,
            parentId: parentId,
            depth: depth,
            order: order,
            searchNormalized: searchNormalized,
            searchInitials: searchInitials,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$FoldersTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({parentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                      dynamic>>(state) {
                if (parentId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.parentId,
                    referencedTable:
                        $$FoldersTableReferences._parentIdTable(db),
                    referencedColumn:
                        $$FoldersTableReferences._parentIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$FoldersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FoldersTable,
    FolderRow,
    $$FoldersTableFilterComposer,
    $$FoldersTableOrderingComposer,
    $$FoldersTableAnnotationComposer,
    $$FoldersTableCreateCompanionBuilder,
    $$FoldersTableUpdateCompanionBuilder,
    (FolderRow, $$FoldersTableReferences),
    FolderRow,
    PrefetchHooks Function({bool parentId})>;
typedef $$ItemPathsTableCreateCompanionBuilder = ItemPathsCompanion Function({
  required String itemId,
  Value<String?> l1Id,
  Value<String?> l2Id,
  Value<String?> l3Id,
  Value<int> rowid,
});
typedef $$ItemPathsTableUpdateCompanionBuilder = ItemPathsCompanion Function({
  Value<String> itemId,
  Value<String?> l1Id,
  Value<String?> l2Id,
  Value<String?> l3Id,
  Value<int> rowid,
});

final class $$ItemPathsTableReferences
    extends BaseReferences<_$AppDatabase, $ItemPathsTable, ItemPathRow> {
  $$ItemPathsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ItemsTable _itemIdTable(_$AppDatabase db) => db.items
      .createAlias($_aliasNameGenerator(db.itemPaths.itemId, db.items.id));

  $$ItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$ItemsTableTableManager($_db, $_db.items)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $FoldersTable _l1IdTable(_$AppDatabase db) => db.folders
      .createAlias($_aliasNameGenerator(db.itemPaths.l1Id, db.folders.id));

  $$FoldersTableProcessedTableManager? get l1Id {
    final $_column = $_itemColumn<String>('l1_id');
    if ($_column == null) return null;
    final manager = $$FoldersTableTableManager($_db, $_db.folders)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_l1IdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $FoldersTable _l2IdTable(_$AppDatabase db) => db.folders
      .createAlias($_aliasNameGenerator(db.itemPaths.l2Id, db.folders.id));

  $$FoldersTableProcessedTableManager? get l2Id {
    final $_column = $_itemColumn<String>('l2_id');
    if ($_column == null) return null;
    final manager = $$FoldersTableTableManager($_db, $_db.folders)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_l2IdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $FoldersTable _l3IdTable(_$AppDatabase db) => db.folders
      .createAlias($_aliasNameGenerator(db.itemPaths.l3Id, db.folders.id));

  $$FoldersTableProcessedTableManager? get l3Id {
    final $_column = $_itemColumn<String>('l3_id');
    if ($_column == null) return null;
    final manager = $$FoldersTableTableManager($_db, $_db.folders)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_l3IdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ItemPathsTableFilterComposer
    extends Composer<_$AppDatabase, $ItemPathsTable> {
  $$ItemPathsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$ItemsTableFilterComposer get itemId {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.itemId,
        referencedTable: $db.items,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItemsTableFilterComposer(
              $db: $db,
              $table: $db.items,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$FoldersTableFilterComposer get l1Id {
    final $$FoldersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.l1Id,
        referencedTable: $db.folders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FoldersTableFilterComposer(
              $db: $db,
              $table: $db.folders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$FoldersTableFilterComposer get l2Id {
    final $$FoldersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.l2Id,
        referencedTable: $db.folders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FoldersTableFilterComposer(
              $db: $db,
              $table: $db.folders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$FoldersTableFilterComposer get l3Id {
    final $$FoldersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.l3Id,
        referencedTable: $db.folders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FoldersTableFilterComposer(
              $db: $db,
              $table: $db.folders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ItemPathsTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemPathsTable> {
  $$ItemPathsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$ItemsTableOrderingComposer get itemId {
    final $$ItemsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.itemId,
        referencedTable: $db.items,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItemsTableOrderingComposer(
              $db: $db,
              $table: $db.items,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$FoldersTableOrderingComposer get l1Id {
    final $$FoldersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.l1Id,
        referencedTable: $db.folders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FoldersTableOrderingComposer(
              $db: $db,
              $table: $db.folders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$FoldersTableOrderingComposer get l2Id {
    final $$FoldersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.l2Id,
        referencedTable: $db.folders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FoldersTableOrderingComposer(
              $db: $db,
              $table: $db.folders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$FoldersTableOrderingComposer get l3Id {
    final $$FoldersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.l3Id,
        referencedTable: $db.folders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FoldersTableOrderingComposer(
              $db: $db,
              $table: $db.folders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ItemPathsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemPathsTable> {
  $$ItemPathsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$ItemsTableAnnotationComposer get itemId {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.itemId,
        referencedTable: $db.items,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItemsTableAnnotationComposer(
              $db: $db,
              $table: $db.items,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$FoldersTableAnnotationComposer get l1Id {
    final $$FoldersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.l1Id,
        referencedTable: $db.folders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FoldersTableAnnotationComposer(
              $db: $db,
              $table: $db.folders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$FoldersTableAnnotationComposer get l2Id {
    final $$FoldersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.l2Id,
        referencedTable: $db.folders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FoldersTableAnnotationComposer(
              $db: $db,
              $table: $db.folders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$FoldersTableAnnotationComposer get l3Id {
    final $$FoldersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.l3Id,
        referencedTable: $db.folders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FoldersTableAnnotationComposer(
              $db: $db,
              $table: $db.folders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ItemPathsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ItemPathsTable,
    ItemPathRow,
    $$ItemPathsTableFilterComposer,
    $$ItemPathsTableOrderingComposer,
    $$ItemPathsTableAnnotationComposer,
    $$ItemPathsTableCreateCompanionBuilder,
    $$ItemPathsTableUpdateCompanionBuilder,
    (ItemPathRow, $$ItemPathsTableReferences),
    ItemPathRow,
    PrefetchHooks Function({bool itemId, bool l1Id, bool l2Id, bool l3Id})> {
  $$ItemPathsTableTableManager(_$AppDatabase db, $ItemPathsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemPathsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemPathsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemPathsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> itemId = const Value.absent(),
            Value<String?> l1Id = const Value.absent(),
            Value<String?> l2Id = const Value.absent(),
            Value<String?> l3Id = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ItemPathsCompanion(
            itemId: itemId,
            l1Id: l1Id,
            l2Id: l2Id,
            l3Id: l3Id,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String itemId,
            Value<String?> l1Id = const Value.absent(),
            Value<String?> l2Id = const Value.absent(),
            Value<String?> l3Id = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ItemPathsCompanion.insert(
            itemId: itemId,
            l1Id: l1Id,
            l2Id: l2Id,
            l3Id: l3Id,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ItemPathsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {itemId = false, l1Id = false, l2Id = false, l3Id = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                      dynamic>>(state) {
                if (itemId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.itemId,
                    referencedTable:
                        $$ItemPathsTableReferences._itemIdTable(db),
                    referencedColumn:
                        $$ItemPathsTableReferences._itemIdTable(db).id,
                  ) as T;
                }
                if (l1Id) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.l1Id,
                    referencedTable: $$ItemPathsTableReferences._l1IdTable(db),
                    referencedColumn:
                        $$ItemPathsTableReferences._l1IdTable(db).id,
                  ) as T;
                }
                if (l2Id) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.l2Id,
                    referencedTable: $$ItemPathsTableReferences._l2IdTable(db),
                    referencedColumn:
                        $$ItemPathsTableReferences._l2IdTable(db).id,
                  ) as T;
                }
                if (l3Id) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.l3Id,
                    referencedTable: $$ItemPathsTableReferences._l3IdTable(db),
                    referencedColumn:
                        $$ItemPathsTableReferences._l3IdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ItemPathsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ItemPathsTable,
    ItemPathRow,
    $$ItemPathsTableFilterComposer,
    $$ItemPathsTableOrderingComposer,
    $$ItemPathsTableAnnotationComposer,
    $$ItemPathsTableCreateCompanionBuilder,
    $$ItemPathsTableUpdateCompanionBuilder,
    (ItemPathRow, $$ItemPathsTableReferences),
    ItemPathRow,
    PrefetchHooks Function({bool itemId, bool l1Id, bool l2Id, bool l3Id})>;
typedef $$TxnsTableCreateCompanionBuilder = TxnsCompanion Function({
  required String id,
  required String ts,
  required String type,
  required String status,
  required String itemId,
  required int qty,
  required String refType,
  required String refId,
  Value<String?> note,
  Value<String?> memo,
  Value<String?> sourceKey,
  Value<bool> isDeleted,
  Value<String?> deletedAt,
  Value<int> rowid,
});
typedef $$TxnsTableUpdateCompanionBuilder = TxnsCompanion Function({
  Value<String> id,
  Value<String> ts,
  Value<String> type,
  Value<String> status,
  Value<String> itemId,
  Value<int> qty,
  Value<String> refType,
  Value<String> refId,
  Value<String?> note,
  Value<String?> memo,
  Value<String?> sourceKey,
  Value<bool> isDeleted,
  Value<String?> deletedAt,
  Value<int> rowid,
});

final class $$TxnsTableReferences
    extends BaseReferences<_$AppDatabase, $TxnsTable, TxnRow> {
  $$TxnsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ItemsTable _itemIdTable(_$AppDatabase db) =>
      db.items.createAlias($_aliasNameGenerator(db.txns.itemId, db.items.id));

  $$ItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$ItemsTableTableManager($_db, $_db.items)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$TxnsTableFilterComposer extends Composer<_$AppDatabase, $TxnsTable> {
  $$TxnsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get qty => $composableBuilder(
      column: $table.qty, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get refType => $composableBuilder(
      column: $table.refType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get refId => $composableBuilder(
      column: $table.refId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get memo => $composableBuilder(
      column: $table.memo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceKey => $composableBuilder(
      column: $table.sourceKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  $$ItemsTableFilterComposer get itemId {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.itemId,
        referencedTable: $db.items,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItemsTableFilterComposer(
              $db: $db,
              $table: $db.items,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TxnsTableOrderingComposer extends Composer<_$AppDatabase, $TxnsTable> {
  $$TxnsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get qty => $composableBuilder(
      column: $table.qty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get refType => $composableBuilder(
      column: $table.refType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get refId => $composableBuilder(
      column: $table.refId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get memo => $composableBuilder(
      column: $table.memo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceKey => $composableBuilder(
      column: $table.sourceKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  $$ItemsTableOrderingComposer get itemId {
    final $$ItemsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.itemId,
        referencedTable: $db.items,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItemsTableOrderingComposer(
              $db: $db,
              $table: $db.items,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TxnsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TxnsTable> {
  $$TxnsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get qty =>
      $composableBuilder(column: $table.qty, builder: (column) => column);

  GeneratedColumn<String> get refType =>
      $composableBuilder(column: $table.refType, builder: (column) => column);

  GeneratedColumn<String> get refId =>
      $composableBuilder(column: $table.refId, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get memo =>
      $composableBuilder(column: $table.memo, builder: (column) => column);

  GeneratedColumn<String> get sourceKey =>
      $composableBuilder(column: $table.sourceKey, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$ItemsTableAnnotationComposer get itemId {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.itemId,
        referencedTable: $db.items,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItemsTableAnnotationComposer(
              $db: $db,
              $table: $db.items,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TxnsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TxnsTable,
    TxnRow,
    $$TxnsTableFilterComposer,
    $$TxnsTableOrderingComposer,
    $$TxnsTableAnnotationComposer,
    $$TxnsTableCreateCompanionBuilder,
    $$TxnsTableUpdateCompanionBuilder,
    (TxnRow, $$TxnsTableReferences),
    TxnRow,
    PrefetchHooks Function({bool itemId})> {
  $$TxnsTableTableManager(_$AppDatabase db, $TxnsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TxnsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TxnsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TxnsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> ts = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> itemId = const Value.absent(),
            Value<int> qty = const Value.absent(),
            Value<String> refType = const Value.absent(),
            Value<String> refId = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String?> memo = const Value.absent(),
            Value<String?> sourceKey = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<String?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TxnsCompanion(
            id: id,
            ts: ts,
            type: type,
            status: status,
            itemId: itemId,
            qty: qty,
            refType: refType,
            refId: refId,
            note: note,
            memo: memo,
            sourceKey: sourceKey,
            isDeleted: isDeleted,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String ts,
            required String type,
            required String status,
            required String itemId,
            required int qty,
            required String refType,
            required String refId,
            Value<String?> note = const Value.absent(),
            Value<String?> memo = const Value.absent(),
            Value<String?> sourceKey = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<String?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TxnsCompanion.insert(
            id: id,
            ts: ts,
            type: type,
            status: status,
            itemId: itemId,
            qty: qty,
            refType: refType,
            refId: refId,
            note: note,
            memo: memo,
            sourceKey: sourceKey,
            isDeleted: isDeleted,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$TxnsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({itemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                      dynamic>>(state) {
                if (itemId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.itemId,
                    referencedTable: $$TxnsTableReferences._itemIdTable(db),
                    referencedColumn: $$TxnsTableReferences._itemIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$TxnsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TxnsTable,
    TxnRow,
    $$TxnsTableFilterComposer,
    $$TxnsTableOrderingComposer,
    $$TxnsTableAnnotationComposer,
    $$TxnsTableCreateCompanionBuilder,
    $$TxnsTableUpdateCompanionBuilder,
    (TxnRow, $$TxnsTableReferences),
    TxnRow,
    PrefetchHooks Function({bool itemId})>;
typedef $$BomRowsTableCreateCompanionBuilder = BomRowsCompanion Function({
  required String root,
  required String parentItemId,
  required String componentItemId,
  required String kind,
  required double qtyPer,
  Value<double> wastePct,
  Value<int> rowid,
});
typedef $$BomRowsTableUpdateCompanionBuilder = BomRowsCompanion Function({
  Value<String> root,
  Value<String> parentItemId,
  Value<String> componentItemId,
  Value<String> kind,
  Value<double> qtyPer,
  Value<double> wastePct,
  Value<int> rowid,
});

final class $$BomRowsTableReferences
    extends BaseReferences<_$AppDatabase, $BomRowsTable, BomRowDb> {
  $$BomRowsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ItemsTable _parentItemIdTable(_$AppDatabase db) => db.items
      .createAlias($_aliasNameGenerator(db.bomRows.parentItemId, db.items.id));

  $$ItemsTableProcessedTableManager get parentItemId {
    final $_column = $_itemColumn<String>('parent_item_id')!;

    final manager = $$ItemsTableTableManager($_db, $_db.items)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $ItemsTable _componentItemIdTable(_$AppDatabase db) =>
      db.items.createAlias(
          $_aliasNameGenerator(db.bomRows.componentItemId, db.items.id));

  $$ItemsTableProcessedTableManager get componentItemId {
    final $_column = $_itemColumn<String>('component_item_id')!;

    final manager = $$ItemsTableTableManager($_db, $_db.items)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_componentItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$BomRowsTableFilterComposer
    extends Composer<_$AppDatabase, $BomRowsTable> {
  $$BomRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get root => $composableBuilder(
      column: $table.root, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get qtyPer => $composableBuilder(
      column: $table.qtyPer, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get wastePct => $composableBuilder(
      column: $table.wastePct, builder: (column) => ColumnFilters(column));

  $$ItemsTableFilterComposer get parentItemId {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parentItemId,
        referencedTable: $db.items,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItemsTableFilterComposer(
              $db: $db,
              $table: $db.items,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ItemsTableFilterComposer get componentItemId {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.componentItemId,
        referencedTable: $db.items,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItemsTableFilterComposer(
              $db: $db,
              $table: $db.items,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BomRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $BomRowsTable> {
  $$BomRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get root => $composableBuilder(
      column: $table.root, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get qtyPer => $composableBuilder(
      column: $table.qtyPer, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get wastePct => $composableBuilder(
      column: $table.wastePct, builder: (column) => ColumnOrderings(column));

  $$ItemsTableOrderingComposer get parentItemId {
    final $$ItemsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parentItemId,
        referencedTable: $db.items,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItemsTableOrderingComposer(
              $db: $db,
              $table: $db.items,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ItemsTableOrderingComposer get componentItemId {
    final $$ItemsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.componentItemId,
        referencedTable: $db.items,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItemsTableOrderingComposer(
              $db: $db,
              $table: $db.items,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BomRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BomRowsTable> {
  $$BomRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get root =>
      $composableBuilder(column: $table.root, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<double> get qtyPer =>
      $composableBuilder(column: $table.qtyPer, builder: (column) => column);

  GeneratedColumn<double> get wastePct =>
      $composableBuilder(column: $table.wastePct, builder: (column) => column);

  $$ItemsTableAnnotationComposer get parentItemId {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parentItemId,
        referencedTable: $db.items,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItemsTableAnnotationComposer(
              $db: $db,
              $table: $db.items,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ItemsTableAnnotationComposer get componentItemId {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.componentItemId,
        referencedTable: $db.items,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItemsTableAnnotationComposer(
              $db: $db,
              $table: $db.items,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BomRowsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BomRowsTable,
    BomRowDb,
    $$BomRowsTableFilterComposer,
    $$BomRowsTableOrderingComposer,
    $$BomRowsTableAnnotationComposer,
    $$BomRowsTableCreateCompanionBuilder,
    $$BomRowsTableUpdateCompanionBuilder,
    (BomRowDb, $$BomRowsTableReferences),
    BomRowDb,
    PrefetchHooks Function({bool parentItemId, bool componentItemId})> {
  $$BomRowsTableTableManager(_$AppDatabase db, $BomRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BomRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BomRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BomRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> root = const Value.absent(),
            Value<String> parentItemId = const Value.absent(),
            Value<String> componentItemId = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<double> qtyPer = const Value.absent(),
            Value<double> wastePct = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BomRowsCompanion(
            root: root,
            parentItemId: parentItemId,
            componentItemId: componentItemId,
            kind: kind,
            qtyPer: qtyPer,
            wastePct: wastePct,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String root,
            required String parentItemId,
            required String componentItemId,
            required String kind,
            required double qtyPer,
            Value<double> wastePct = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BomRowsCompanion.insert(
            root: root,
            parentItemId: parentItemId,
            componentItemId: componentItemId,
            kind: kind,
            qtyPer: qtyPer,
            wastePct: wastePct,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$BomRowsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {parentItemId = false, componentItemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                      dynamic>>(state) {
                if (parentItemId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.parentItemId,
                    referencedTable:
                        $$BomRowsTableReferences._parentItemIdTable(db),
                    referencedColumn:
                        $$BomRowsTableReferences._parentItemIdTable(db).id,
                  ) as T;
                }
                if (componentItemId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.componentItemId,
                    referencedTable:
                        $$BomRowsTableReferences._componentItemIdTable(db),
                    referencedColumn:
                        $$BomRowsTableReferences._componentItemIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$BomRowsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BomRowsTable,
    BomRowDb,
    $$BomRowsTableFilterComposer,
    $$BomRowsTableOrderingComposer,
    $$BomRowsTableAnnotationComposer,
    $$BomRowsTableCreateCompanionBuilder,
    $$BomRowsTableUpdateCompanionBuilder,
    (BomRowDb, $$BomRowsTableReferences),
    BomRowDb,
    PrefetchHooks Function({bool parentItemId, bool componentItemId})>;
typedef $$OrdersTableCreateCompanionBuilder = OrdersCompanion Function({
  required String id,
  required String date,
  required String customer,
  Value<String?> memo,
  required String status,
  Value<bool> isDeleted,
  Value<String?> updatedAt,
  Value<String?> deletedAt,
  Value<String?> shippedAt,
  Value<String?> dueDate,
  Value<int> rowid,
});
typedef $$OrdersTableUpdateCompanionBuilder = OrdersCompanion Function({
  Value<String> id,
  Value<String> date,
  Value<String> customer,
  Value<String?> memo,
  Value<String> status,
  Value<bool> isDeleted,
  Value<String?> updatedAt,
  Value<String?> deletedAt,
  Value<String?> shippedAt,
  Value<String?> dueDate,
  Value<int> rowid,
});

final class $$OrdersTableReferences
    extends BaseReferences<_$AppDatabase, $OrdersTable, OrderRow> {
  $$OrdersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$OrderLinesTable, List<OrderLineRow>>
      _orderLinesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.orderLines,
          aliasName: $_aliasNameGenerator(db.orders.id, db.orderLines.orderId));

  $$OrderLinesTableProcessedTableManager get orderLinesRefs {
    final manager = $$OrderLinesTableTableManager($_db, $_db.orderLines)
        .filter((f) => f.orderId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_orderLinesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$WorksTable, List<WorkRow>> _worksRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.works,
          aliasName: $_aliasNameGenerator(db.orders.id, db.works.orderId));

  $$WorksTableProcessedTableManager get worksRefs {
    final manager = $$WorksTableTableManager($_db, $_db.works)
        .filter((f) => f.orderId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_worksRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$OrdersTableFilterComposer
    extends Composer<_$AppDatabase, $OrdersTable> {
  $$OrdersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customer => $composableBuilder(
      column: $table.customer, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get memo => $composableBuilder(
      column: $table.memo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get shippedAt => $composableBuilder(
      column: $table.shippedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dueDate => $composableBuilder(
      column: $table.dueDate, builder: (column) => ColumnFilters(column));

  Expression<bool> orderLinesRefs(
      Expression<bool> Function($$OrderLinesTableFilterComposer f) f) {
    final $$OrderLinesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.orderLines,
        getReferencedColumn: (t) => t.orderId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OrderLinesTableFilterComposer(
              $db: $db,
              $table: $db.orderLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> worksRefs(
      Expression<bool> Function($$WorksTableFilterComposer f) f) {
    final $$WorksTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.works,
        getReferencedColumn: (t) => t.orderId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WorksTableFilterComposer(
              $db: $db,
              $table: $db.works,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$OrdersTableOrderingComposer
    extends Composer<_$AppDatabase, $OrdersTable> {
  $$OrdersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customer => $composableBuilder(
      column: $table.customer, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get memo => $composableBuilder(
      column: $table.memo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get shippedAt => $composableBuilder(
      column: $table.shippedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dueDate => $composableBuilder(
      column: $table.dueDate, builder: (column) => ColumnOrderings(column));
}

class $$OrdersTableAnnotationComposer
    extends Composer<_$AppDatabase, $OrdersTable> {
  $$OrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get customer =>
      $composableBuilder(column: $table.customer, builder: (column) => column);

  GeneratedColumn<String> get memo =>
      $composableBuilder(column: $table.memo, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get shippedAt =>
      $composableBuilder(column: $table.shippedAt, builder: (column) => column);

  GeneratedColumn<String> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  Expression<T> orderLinesRefs<T extends Object>(
      Expression<T> Function($$OrderLinesTableAnnotationComposer a) f) {
    final $$OrderLinesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.orderLines,
        getReferencedColumn: (t) => t.orderId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OrderLinesTableAnnotationComposer(
              $db: $db,
              $table: $db.orderLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> worksRefs<T extends Object>(
      Expression<T> Function($$WorksTableAnnotationComposer a) f) {
    final $$WorksTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.works,
        getReferencedColumn: (t) => t.orderId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WorksTableAnnotationComposer(
              $db: $db,
              $table: $db.works,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$OrdersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OrdersTable,
    OrderRow,
    $$OrdersTableFilterComposer,
    $$OrdersTableOrderingComposer,
    $$OrdersTableAnnotationComposer,
    $$OrdersTableCreateCompanionBuilder,
    $$OrdersTableUpdateCompanionBuilder,
    (OrderRow, $$OrdersTableReferences),
    OrderRow,
    PrefetchHooks Function({bool orderLinesRefs, bool worksRefs})> {
  $$OrdersTableTableManager(_$AppDatabase db, $OrdersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OrdersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OrdersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OrdersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> date = const Value.absent(),
            Value<String> customer = const Value.absent(),
            Value<String?> memo = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<String?> updatedAt = const Value.absent(),
            Value<String?> deletedAt = const Value.absent(),
            Value<String?> shippedAt = const Value.absent(),
            Value<String?> dueDate = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OrdersCompanion(
            id: id,
            date: date,
            customer: customer,
            memo: memo,
            status: status,
            isDeleted: isDeleted,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            shippedAt: shippedAt,
            dueDate: dueDate,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String date,
            required String customer,
            Value<String?> memo = const Value.absent(),
            required String status,
            Value<bool> isDeleted = const Value.absent(),
            Value<String?> updatedAt = const Value.absent(),
            Value<String?> deletedAt = const Value.absent(),
            Value<String?> shippedAt = const Value.absent(),
            Value<String?> dueDate = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OrdersCompanion.insert(
            id: id,
            date: date,
            customer: customer,
            memo: memo,
            status: status,
            isDeleted: isDeleted,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            shippedAt: shippedAt,
            dueDate: dueDate,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$OrdersTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({orderLinesRefs = false, worksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (orderLinesRefs) db.orderLines,
                if (worksRefs) db.works
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (orderLinesRefs)
                    await $_getPrefetchedData<OrderRow, $OrdersTable,
                            OrderLineRow>(
                        currentTable: table,
                        referencedTable:
                            $$OrdersTableReferences._orderLinesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$OrdersTableReferences(db, table, p0)
                                .orderLinesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.orderId == item.id),
                        typedResults: items),
                  if (worksRefs)
                    await $_getPrefetchedData<OrderRow, $OrdersTable, WorkRow>(
                        currentTable: table,
                        referencedTable:
                            $$OrdersTableReferences._worksRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$OrdersTableReferences(db, table, p0).worksRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.orderId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$OrdersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OrdersTable,
    OrderRow,
    $$OrdersTableFilterComposer,
    $$OrdersTableOrderingComposer,
    $$OrdersTableAnnotationComposer,
    $$OrdersTableCreateCompanionBuilder,
    $$OrdersTableUpdateCompanionBuilder,
    (OrderRow, $$OrdersTableReferences),
    OrderRow,
    PrefetchHooks Function({bool orderLinesRefs, bool worksRefs})>;
typedef $$OrderLinesTableCreateCompanionBuilder = OrderLinesCompanion Function({
  required String id,
  required String orderId,
  required String itemId,
  required int qty,
  Value<bool> isDeleted,
  Value<String?> deletedAt,
  Value<int> rowid,
});
typedef $$OrderLinesTableUpdateCompanionBuilder = OrderLinesCompanion Function({
  Value<String> id,
  Value<String> orderId,
  Value<String> itemId,
  Value<int> qty,
  Value<bool> isDeleted,
  Value<String?> deletedAt,
  Value<int> rowid,
});

final class $$OrderLinesTableReferences
    extends BaseReferences<_$AppDatabase, $OrderLinesTable, OrderLineRow> {
  $$OrderLinesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $OrdersTable _orderIdTable(_$AppDatabase db) => db.orders
      .createAlias($_aliasNameGenerator(db.orderLines.orderId, db.orders.id));

  $$OrdersTableProcessedTableManager get orderId {
    final $_column = $_itemColumn<String>('order_id')!;

    final manager = $$OrdersTableTableManager($_db, $_db.orders)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_orderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $ItemsTable _itemIdTable(_$AppDatabase db) => db.items
      .createAlias($_aliasNameGenerator(db.orderLines.itemId, db.items.id));

  $$ItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$ItemsTableTableManager($_db, $_db.items)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$OrderLinesTableFilterComposer
    extends Composer<_$AppDatabase, $OrderLinesTable> {
  $$OrderLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get qty => $composableBuilder(
      column: $table.qty, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  $$OrdersTableFilterComposer get orderId {
    final $$OrdersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.orderId,
        referencedTable: $db.orders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OrdersTableFilterComposer(
              $db: $db,
              $table: $db.orders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ItemsTableFilterComposer get itemId {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.itemId,
        referencedTable: $db.items,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItemsTableFilterComposer(
              $db: $db,
              $table: $db.items,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$OrderLinesTableOrderingComposer
    extends Composer<_$AppDatabase, $OrderLinesTable> {
  $$OrderLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get qty => $composableBuilder(
      column: $table.qty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  $$OrdersTableOrderingComposer get orderId {
    final $$OrdersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.orderId,
        referencedTable: $db.orders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OrdersTableOrderingComposer(
              $db: $db,
              $table: $db.orders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ItemsTableOrderingComposer get itemId {
    final $$ItemsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.itemId,
        referencedTable: $db.items,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItemsTableOrderingComposer(
              $db: $db,
              $table: $db.items,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$OrderLinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OrderLinesTable> {
  $$OrderLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get qty =>
      $composableBuilder(column: $table.qty, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$OrdersTableAnnotationComposer get orderId {
    final $$OrdersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.orderId,
        referencedTable: $db.orders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OrdersTableAnnotationComposer(
              $db: $db,
              $table: $db.orders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ItemsTableAnnotationComposer get itemId {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.itemId,
        referencedTable: $db.items,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItemsTableAnnotationComposer(
              $db: $db,
              $table: $db.items,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$OrderLinesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OrderLinesTable,
    OrderLineRow,
    $$OrderLinesTableFilterComposer,
    $$OrderLinesTableOrderingComposer,
    $$OrderLinesTableAnnotationComposer,
    $$OrderLinesTableCreateCompanionBuilder,
    $$OrderLinesTableUpdateCompanionBuilder,
    (OrderLineRow, $$OrderLinesTableReferences),
    OrderLineRow,
    PrefetchHooks Function({bool orderId, bool itemId})> {
  $$OrderLinesTableTableManager(_$AppDatabase db, $OrderLinesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OrderLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OrderLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OrderLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> orderId = const Value.absent(),
            Value<String> itemId = const Value.absent(),
            Value<int> qty = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<String?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OrderLinesCompanion(
            id: id,
            orderId: orderId,
            itemId: itemId,
            qty: qty,
            isDeleted: isDeleted,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String orderId,
            required String itemId,
            required int qty,
            Value<bool> isDeleted = const Value.absent(),
            Value<String?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OrderLinesCompanion.insert(
            id: id,
            orderId: orderId,
            itemId: itemId,
            qty: qty,
            isDeleted: isDeleted,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$OrderLinesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({orderId = false, itemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                      dynamic>>(state) {
                if (orderId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.orderId,
                    referencedTable:
                        $$OrderLinesTableReferences._orderIdTable(db),
                    referencedColumn:
                        $$OrderLinesTableReferences._orderIdTable(db).id,
                  ) as T;
                }
                if (itemId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.itemId,
                    referencedTable:
                        $$OrderLinesTableReferences._itemIdTable(db),
                    referencedColumn:
                        $$OrderLinesTableReferences._itemIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$OrderLinesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OrderLinesTable,
    OrderLineRow,
    $$OrderLinesTableFilterComposer,
    $$OrderLinesTableOrderingComposer,
    $$OrderLinesTableAnnotationComposer,
    $$OrderLinesTableCreateCompanionBuilder,
    $$OrderLinesTableUpdateCompanionBuilder,
    (OrderLineRow, $$OrderLinesTableReferences),
    OrderLineRow,
    PrefetchHooks Function({bool orderId, bool itemId})>;
typedef $$WorksTableCreateCompanionBuilder = WorksCompanion Function({
  required String id,
  required String itemId,
  required int qty,
  Value<int> doneQty,
  Value<String?> orderId,
  Value<String?> parentWorkId,
  required String status,
  required String createdAt,
  Value<String?> updatedAt,
  Value<String?> sourceKey,
  Value<bool> isDeleted,
  Value<String?> deletedAt,
  Value<String?> startedAt,
  Value<String?> finishedAt,
  Value<int> rowid,
});
typedef $$WorksTableUpdateCompanionBuilder = WorksCompanion Function({
  Value<String> id,
  Value<String> itemId,
  Value<int> qty,
  Value<int> doneQty,
  Value<String?> orderId,
  Value<String?> parentWorkId,
  Value<String> status,
  Value<String> createdAt,
  Value<String?> updatedAt,
  Value<String?> sourceKey,
  Value<bool> isDeleted,
  Value<String?> deletedAt,
  Value<String?> startedAt,
  Value<String?> finishedAt,
  Value<int> rowid,
});

final class $$WorksTableReferences
    extends BaseReferences<_$AppDatabase, $WorksTable, WorkRow> {
  $$WorksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ItemsTable _itemIdTable(_$AppDatabase db) =>
      db.items.createAlias($_aliasNameGenerator(db.works.itemId, db.items.id));

  $$ItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$ItemsTableTableManager($_db, $_db.items)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $OrdersTable _orderIdTable(_$AppDatabase db) => db.orders
      .createAlias($_aliasNameGenerator(db.works.orderId, db.orders.id));

  $$OrdersTableProcessedTableManager? get orderId {
    final $_column = $_itemColumn<String>('order_id');
    if ($_column == null) return null;
    final manager = $$OrdersTableTableManager($_db, $_db.orders)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_orderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$WorksTableFilterComposer extends Composer<_$AppDatabase, $WorksTable> {
  $$WorksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get qty => $composableBuilder(
      column: $table.qty, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get doneQty => $composableBuilder(
      column: $table.doneQty, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parentWorkId => $composableBuilder(
      column: $table.parentWorkId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceKey => $composableBuilder(
      column: $table.sourceKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get finishedAt => $composableBuilder(
      column: $table.finishedAt, builder: (column) => ColumnFilters(column));

  $$ItemsTableFilterComposer get itemId {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.itemId,
        referencedTable: $db.items,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItemsTableFilterComposer(
              $db: $db,
              $table: $db.items,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$OrdersTableFilterComposer get orderId {
    final $$OrdersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.orderId,
        referencedTable: $db.orders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OrdersTableFilterComposer(
              $db: $db,
              $table: $db.orders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WorksTableOrderingComposer
    extends Composer<_$AppDatabase, $WorksTable> {
  $$WorksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get qty => $composableBuilder(
      column: $table.qty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get doneQty => $composableBuilder(
      column: $table.doneQty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parentWorkId => $composableBuilder(
      column: $table.parentWorkId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceKey => $composableBuilder(
      column: $table.sourceKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get finishedAt => $composableBuilder(
      column: $table.finishedAt, builder: (column) => ColumnOrderings(column));

  $$ItemsTableOrderingComposer get itemId {
    final $$ItemsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.itemId,
        referencedTable: $db.items,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItemsTableOrderingComposer(
              $db: $db,
              $table: $db.items,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$OrdersTableOrderingComposer get orderId {
    final $$OrdersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.orderId,
        referencedTable: $db.orders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OrdersTableOrderingComposer(
              $db: $db,
              $table: $db.orders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WorksTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorksTable> {
  $$WorksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get qty =>
      $composableBuilder(column: $table.qty, builder: (column) => column);

  GeneratedColumn<int> get doneQty =>
      $composableBuilder(column: $table.doneQty, builder: (column) => column);

  GeneratedColumn<String> get parentWorkId => $composableBuilder(
      column: $table.parentWorkId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get sourceKey =>
      $composableBuilder(column: $table.sourceKey, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<String> get finishedAt => $composableBuilder(
      column: $table.finishedAt, builder: (column) => column);

  $$ItemsTableAnnotationComposer get itemId {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.itemId,
        referencedTable: $db.items,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItemsTableAnnotationComposer(
              $db: $db,
              $table: $db.items,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$OrdersTableAnnotationComposer get orderId {
    final $$OrdersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.orderId,
        referencedTable: $db.orders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OrdersTableAnnotationComposer(
              $db: $db,
              $table: $db.orders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WorksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WorksTable,
    WorkRow,
    $$WorksTableFilterComposer,
    $$WorksTableOrderingComposer,
    $$WorksTableAnnotationComposer,
    $$WorksTableCreateCompanionBuilder,
    $$WorksTableUpdateCompanionBuilder,
    (WorkRow, $$WorksTableReferences),
    WorkRow,
    PrefetchHooks Function({bool itemId, bool orderId})> {
  $$WorksTableTableManager(_$AppDatabase db, $WorksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> itemId = const Value.absent(),
            Value<int> qty = const Value.absent(),
            Value<int> doneQty = const Value.absent(),
            Value<String?> orderId = const Value.absent(),
            Value<String?> parentWorkId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> createdAt = const Value.absent(),
            Value<String?> updatedAt = const Value.absent(),
            Value<String?> sourceKey = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<String?> deletedAt = const Value.absent(),
            Value<String?> startedAt = const Value.absent(),
            Value<String?> finishedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WorksCompanion(
            id: id,
            itemId: itemId,
            qty: qty,
            doneQty: doneQty,
            orderId: orderId,
            parentWorkId: parentWorkId,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            sourceKey: sourceKey,
            isDeleted: isDeleted,
            deletedAt: deletedAt,
            startedAt: startedAt,
            finishedAt: finishedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String itemId,
            required int qty,
            Value<int> doneQty = const Value.absent(),
            Value<String?> orderId = const Value.absent(),
            Value<String?> parentWorkId = const Value.absent(),
            required String status,
            required String createdAt,
            Value<String?> updatedAt = const Value.absent(),
            Value<String?> sourceKey = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<String?> deletedAt = const Value.absent(),
            Value<String?> startedAt = const Value.absent(),
            Value<String?> finishedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WorksCompanion.insert(
            id: id,
            itemId: itemId,
            qty: qty,
            doneQty: doneQty,
            orderId: orderId,
            parentWorkId: parentWorkId,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            sourceKey: sourceKey,
            isDeleted: isDeleted,
            deletedAt: deletedAt,
            startedAt: startedAt,
            finishedAt: finishedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$WorksTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({itemId = false, orderId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                      dynamic>>(state) {
                if (itemId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.itemId,
                    referencedTable: $$WorksTableReferences._itemIdTable(db),
                    referencedColumn:
                        $$WorksTableReferences._itemIdTable(db).id,
                  ) as T;
                }
                if (orderId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.orderId,
                    referencedTable: $$WorksTableReferences._orderIdTable(db),
                    referencedColumn:
                        $$WorksTableReferences._orderIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$WorksTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WorksTable,
    WorkRow,
    $$WorksTableFilterComposer,
    $$WorksTableOrderingComposer,
    $$WorksTableAnnotationComposer,
    $$WorksTableCreateCompanionBuilder,
    $$WorksTableUpdateCompanionBuilder,
    (WorkRow, $$WorksTableReferences),
    WorkRow,
    PrefetchHooks Function({bool itemId, bool orderId})>;
typedef $$PurchaseOrdersTableCreateCompanionBuilder = PurchaseOrdersCompanion
    Function({
  required String id,
  required String supplierName,
  required String eta,
  required String status,
  required String createdAt,
  required String updatedAt,
  Value<bool> isDeleted,
  Value<String?> memo,
  Value<String?> deletedAt,
  Value<String?> orderId,
  Value<String?> receivedAt,
  Value<int> rowid,
});
typedef $$PurchaseOrdersTableUpdateCompanionBuilder = PurchaseOrdersCompanion
    Function({
  Value<String> id,
  Value<String> supplierName,
  Value<String> eta,
  Value<String> status,
  Value<String> createdAt,
  Value<String> updatedAt,
  Value<bool> isDeleted,
  Value<String?> memo,
  Value<String?> deletedAt,
  Value<String?> orderId,
  Value<String?> receivedAt,
  Value<int> rowid,
});

final class $$PurchaseOrdersTableReferences extends BaseReferences<
    _$AppDatabase, $PurchaseOrdersTable, PurchaseOrderRow> {
  $$PurchaseOrdersTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PurchaseLinesTable, List<PurchaseLineRow>>
      _purchaseLinesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.purchaseLines,
              aliasName: $_aliasNameGenerator(
                  db.purchaseOrders.id, db.purchaseLines.orderId));

  $$PurchaseLinesTableProcessedTableManager get purchaseLinesRefs {
    final manager = $$PurchaseLinesTableTableManager($_db, $_db.purchaseLines)
        .filter((f) => f.orderId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_purchaseLinesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$PurchaseOrdersTableFilterComposer
    extends Composer<_$AppDatabase, $PurchaseOrdersTable> {
  $$PurchaseOrdersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get supplierName => $composableBuilder(
      column: $table.supplierName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get eta => $composableBuilder(
      column: $table.eta, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get memo => $composableBuilder(
      column: $table.memo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get orderId => $composableBuilder(
      column: $table.orderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> purchaseLinesRefs(
      Expression<bool> Function($$PurchaseLinesTableFilterComposer f) f) {
    final $$PurchaseLinesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.purchaseLines,
        getReferencedColumn: (t) => t.orderId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PurchaseLinesTableFilterComposer(
              $db: $db,
              $table: $db.purchaseLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PurchaseOrdersTableOrderingComposer
    extends Composer<_$AppDatabase, $PurchaseOrdersTable> {
  $$PurchaseOrdersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get supplierName => $composableBuilder(
      column: $table.supplierName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get eta => $composableBuilder(
      column: $table.eta, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get memo => $composableBuilder(
      column: $table.memo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get orderId => $composableBuilder(
      column: $table.orderId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => ColumnOrderings(column));
}

class $$PurchaseOrdersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PurchaseOrdersTable> {
  $$PurchaseOrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get supplierName => $composableBuilder(
      column: $table.supplierName, builder: (column) => column);

  GeneratedColumn<String> get eta =>
      $composableBuilder(column: $table.eta, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get memo =>
      $composableBuilder(column: $table.memo, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get orderId =>
      $composableBuilder(column: $table.orderId, builder: (column) => column);

  GeneratedColumn<String> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => column);

  Expression<T> purchaseLinesRefs<T extends Object>(
      Expression<T> Function($$PurchaseLinesTableAnnotationComposer a) f) {
    final $$PurchaseLinesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.purchaseLines,
        getReferencedColumn: (t) => t.orderId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PurchaseLinesTableAnnotationComposer(
              $db: $db,
              $table: $db.purchaseLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PurchaseOrdersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PurchaseOrdersTable,
    PurchaseOrderRow,
    $$PurchaseOrdersTableFilterComposer,
    $$PurchaseOrdersTableOrderingComposer,
    $$PurchaseOrdersTableAnnotationComposer,
    $$PurchaseOrdersTableCreateCompanionBuilder,
    $$PurchaseOrdersTableUpdateCompanionBuilder,
    (PurchaseOrderRow, $$PurchaseOrdersTableReferences),
    PurchaseOrderRow,
    PrefetchHooks Function({bool purchaseLinesRefs})> {
  $$PurchaseOrdersTableTableManager(
      _$AppDatabase db, $PurchaseOrdersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PurchaseOrdersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PurchaseOrdersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PurchaseOrdersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> supplierName = const Value.absent(),
            Value<String> eta = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> createdAt = const Value.absent(),
            Value<String> updatedAt = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<String?> memo = const Value.absent(),
            Value<String?> deletedAt = const Value.absent(),
            Value<String?> orderId = const Value.absent(),
            Value<String?> receivedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PurchaseOrdersCompanion(
            id: id,
            supplierName: supplierName,
            eta: eta,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isDeleted: isDeleted,
            memo: memo,
            deletedAt: deletedAt,
            orderId: orderId,
            receivedAt: receivedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String supplierName,
            required String eta,
            required String status,
            required String createdAt,
            required String updatedAt,
            Value<bool> isDeleted = const Value.absent(),
            Value<String?> memo = const Value.absent(),
            Value<String?> deletedAt = const Value.absent(),
            Value<String?> orderId = const Value.absent(),
            Value<String?> receivedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PurchaseOrdersCompanion.insert(
            id: id,
            supplierName: supplierName,
            eta: eta,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isDeleted: isDeleted,
            memo: memo,
            deletedAt: deletedAt,
            orderId: orderId,
            receivedAt: receivedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$PurchaseOrdersTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({purchaseLinesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (purchaseLinesRefs) db.purchaseLines
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (purchaseLinesRefs)
                    await $_getPrefetchedData<PurchaseOrderRow,
                            $PurchaseOrdersTable, PurchaseLineRow>(
                        currentTable: table,
                        referencedTable: $$PurchaseOrdersTableReferences
                            ._purchaseLinesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$PurchaseOrdersTableReferences(db, table, p0)
                                .purchaseLinesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.orderId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$PurchaseOrdersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PurchaseOrdersTable,
    PurchaseOrderRow,
    $$PurchaseOrdersTableFilterComposer,
    $$PurchaseOrdersTableOrderingComposer,
    $$PurchaseOrdersTableAnnotationComposer,
    $$PurchaseOrdersTableCreateCompanionBuilder,
    $$PurchaseOrdersTableUpdateCompanionBuilder,
    (PurchaseOrderRow, $$PurchaseOrdersTableReferences),
    PurchaseOrderRow,
    PrefetchHooks Function({bool purchaseLinesRefs})>;
typedef $$PurchaseLinesTableCreateCompanionBuilder = PurchaseLinesCompanion
    Function({
  required String id,
  required String orderId,
  required String itemId,
  required String name,
  required String unit,
  required double qty,
  Value<String?> note,
  Value<String?> memo,
  Value<String?> colorNo,
  Value<bool> isDeleted,
  Value<String?> deletedAt,
  Value<int> rowid,
});
typedef $$PurchaseLinesTableUpdateCompanionBuilder = PurchaseLinesCompanion
    Function({
  Value<String> id,
  Value<String> orderId,
  Value<String> itemId,
  Value<String> name,
  Value<String> unit,
  Value<double> qty,
  Value<String?> note,
  Value<String?> memo,
  Value<String?> colorNo,
  Value<bool> isDeleted,
  Value<String?> deletedAt,
  Value<int> rowid,
});

final class $$PurchaseLinesTableReferences extends BaseReferences<_$AppDatabase,
    $PurchaseLinesTable, PurchaseLineRow> {
  $$PurchaseLinesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $PurchaseOrdersTable _orderIdTable(_$AppDatabase db) =>
      db.purchaseOrders.createAlias(
          $_aliasNameGenerator(db.purchaseLines.orderId, db.purchaseOrders.id));

  $$PurchaseOrdersTableProcessedTableManager get orderId {
    final $_column = $_itemColumn<String>('order_id')!;

    final manager = $$PurchaseOrdersTableTableManager($_db, $_db.purchaseOrders)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_orderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $ItemsTable _itemIdTable(_$AppDatabase db) => db.items
      .createAlias($_aliasNameGenerator(db.purchaseLines.itemId, db.items.id));

  $$ItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$ItemsTableTableManager($_db, $_db.items)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$PurchaseLinesTableFilterComposer
    extends Composer<_$AppDatabase, $PurchaseLinesTable> {
  $$PurchaseLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get qty => $composableBuilder(
      column: $table.qty, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get memo => $composableBuilder(
      column: $table.memo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get colorNo => $composableBuilder(
      column: $table.colorNo, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  $$PurchaseOrdersTableFilterComposer get orderId {
    final $$PurchaseOrdersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.orderId,
        referencedTable: $db.purchaseOrders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PurchaseOrdersTableFilterComposer(
              $db: $db,
              $table: $db.purchaseOrders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ItemsTableFilterComposer get itemId {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.itemId,
        referencedTable: $db.items,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItemsTableFilterComposer(
              $db: $db,
              $table: $db.items,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PurchaseLinesTableOrderingComposer
    extends Composer<_$AppDatabase, $PurchaseLinesTable> {
  $$PurchaseLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get qty => $composableBuilder(
      column: $table.qty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get memo => $composableBuilder(
      column: $table.memo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get colorNo => $composableBuilder(
      column: $table.colorNo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  $$PurchaseOrdersTableOrderingComposer get orderId {
    final $$PurchaseOrdersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.orderId,
        referencedTable: $db.purchaseOrders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PurchaseOrdersTableOrderingComposer(
              $db: $db,
              $table: $db.purchaseOrders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ItemsTableOrderingComposer get itemId {
    final $$ItemsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.itemId,
        referencedTable: $db.items,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItemsTableOrderingComposer(
              $db: $db,
              $table: $db.items,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PurchaseLinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PurchaseLinesTable> {
  $$PurchaseLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<double> get qty =>
      $composableBuilder(column: $table.qty, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get memo =>
      $composableBuilder(column: $table.memo, builder: (column) => column);

  GeneratedColumn<String> get colorNo =>
      $composableBuilder(column: $table.colorNo, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$PurchaseOrdersTableAnnotationComposer get orderId {
    final $$PurchaseOrdersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.orderId,
        referencedTable: $db.purchaseOrders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PurchaseOrdersTableAnnotationComposer(
              $db: $db,
              $table: $db.purchaseOrders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ItemsTableAnnotationComposer get itemId {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.itemId,
        referencedTable: $db.items,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItemsTableAnnotationComposer(
              $db: $db,
              $table: $db.items,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PurchaseLinesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PurchaseLinesTable,
    PurchaseLineRow,
    $$PurchaseLinesTableFilterComposer,
    $$PurchaseLinesTableOrderingComposer,
    $$PurchaseLinesTableAnnotationComposer,
    $$PurchaseLinesTableCreateCompanionBuilder,
    $$PurchaseLinesTableUpdateCompanionBuilder,
    (PurchaseLineRow, $$PurchaseLinesTableReferences),
    PurchaseLineRow,
    PrefetchHooks Function({bool orderId, bool itemId})> {
  $$PurchaseLinesTableTableManager(_$AppDatabase db, $PurchaseLinesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PurchaseLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PurchaseLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PurchaseLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> orderId = const Value.absent(),
            Value<String> itemId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> unit = const Value.absent(),
            Value<double> qty = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String?> memo = const Value.absent(),
            Value<String?> colorNo = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<String?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PurchaseLinesCompanion(
            id: id,
            orderId: orderId,
            itemId: itemId,
            name: name,
            unit: unit,
            qty: qty,
            note: note,
            memo: memo,
            colorNo: colorNo,
            isDeleted: isDeleted,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String orderId,
            required String itemId,
            required String name,
            required String unit,
            required double qty,
            Value<String?> note = const Value.absent(),
            Value<String?> memo = const Value.absent(),
            Value<String?> colorNo = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<String?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PurchaseLinesCompanion.insert(
            id: id,
            orderId: orderId,
            itemId: itemId,
            name: name,
            unit: unit,
            qty: qty,
            note: note,
            memo: memo,
            colorNo: colorNo,
            isDeleted: isDeleted,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$PurchaseLinesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({orderId = false, itemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                      dynamic>>(state) {
                if (orderId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.orderId,
                    referencedTable:
                        $$PurchaseLinesTableReferences._orderIdTable(db),
                    referencedColumn:
                        $$PurchaseLinesTableReferences._orderIdTable(db).id,
                  ) as T;
                }
                if (itemId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.itemId,
                    referencedTable:
                        $$PurchaseLinesTableReferences._itemIdTable(db),
                    referencedColumn:
                        $$PurchaseLinesTableReferences._itemIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$PurchaseLinesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PurchaseLinesTable,
    PurchaseLineRow,
    $$PurchaseLinesTableFilterComposer,
    $$PurchaseLinesTableOrderingComposer,
    $$PurchaseLinesTableAnnotationComposer,
    $$PurchaseLinesTableCreateCompanionBuilder,
    $$PurchaseLinesTableUpdateCompanionBuilder,
    (PurchaseLineRow, $$PurchaseLinesTableReferences),
    PurchaseLineRow,
    PrefetchHooks Function({bool orderId, bool itemId})>;
typedef $$SuppliersTableCreateCompanionBuilder = SuppliersCompanion Function({
  required String id,
  required String name,
  Value<String?> contactName,
  Value<String?> phone,
  Value<String?> email,
  Value<String?> addr,
  Value<String?> memo,
  Value<bool> isActive,
  required String createdAt,
  required String updatedAt,
  Value<int> rowid,
});
typedef $$SuppliersTableUpdateCompanionBuilder = SuppliersCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> contactName,
  Value<String?> phone,
  Value<String?> email,
  Value<String?> addr,
  Value<String?> memo,
  Value<bool> isActive,
  Value<String> createdAt,
  Value<String> updatedAt,
  Value<int> rowid,
});

class $$SuppliersTableFilterComposer
    extends Composer<_$AppDatabase, $SuppliersTable> {
  $$SuppliersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contactName => $composableBuilder(
      column: $table.contactName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get addr => $composableBuilder(
      column: $table.addr, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get memo => $composableBuilder(
      column: $table.memo, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$SuppliersTableOrderingComposer
    extends Composer<_$AppDatabase, $SuppliersTable> {
  $$SuppliersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contactName => $composableBuilder(
      column: $table.contactName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get addr => $composableBuilder(
      column: $table.addr, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get memo => $composableBuilder(
      column: $table.memo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$SuppliersTableAnnotationComposer
    extends Composer<_$AppDatabase, $SuppliersTable> {
  $$SuppliersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get contactName => $composableBuilder(
      column: $table.contactName, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get addr =>
      $composableBuilder(column: $table.addr, builder: (column) => column);

  GeneratedColumn<String> get memo =>
      $composableBuilder(column: $table.memo, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SuppliersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SuppliersTable,
    SupplierRow,
    $$SuppliersTableFilterComposer,
    $$SuppliersTableOrderingComposer,
    $$SuppliersTableAnnotationComposer,
    $$SuppliersTableCreateCompanionBuilder,
    $$SuppliersTableUpdateCompanionBuilder,
    (SupplierRow, BaseReferences<_$AppDatabase, $SuppliersTable, SupplierRow>),
    SupplierRow,
    PrefetchHooks Function()> {
  $$SuppliersTableTableManager(_$AppDatabase db, $SuppliersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SuppliersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SuppliersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SuppliersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> contactName = const Value.absent(),
            Value<String?> phone = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> addr = const Value.absent(),
            Value<String?> memo = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<String> createdAt = const Value.absent(),
            Value<String> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SuppliersCompanion(
            id: id,
            name: name,
            contactName: contactName,
            phone: phone,
            email: email,
            addr: addr,
            memo: memo,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String?> contactName = const Value.absent(),
            Value<String?> phone = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> addr = const Value.absent(),
            Value<String?> memo = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            required String createdAt,
            required String updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              SuppliersCompanion.insert(
            id: id,
            name: name,
            contactName: contactName,
            phone: phone,
            email: email,
            addr: addr,
            memo: memo,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SuppliersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SuppliersTable,
    SupplierRow,
    $$SuppliersTableFilterComposer,
    $$SuppliersTableOrderingComposer,
    $$SuppliersTableAnnotationComposer,
    $$SuppliersTableCreateCompanionBuilder,
    $$SuppliersTableUpdateCompanionBuilder,
    (SupplierRow, BaseReferences<_$AppDatabase, $SuppliersTable, SupplierRow>),
    SupplierRow,
    PrefetchHooks Function()>;
typedef $$LotsTableCreateCompanionBuilder = LotsCompanion Function({
  required String id,
  required String itemId,
  required String lotNo,
  required double receivedQtyRoll,
  required double measuredLengthM,
  required double usableQtyM,
  Value<String> status,
  required String receivedAt,
  Value<int> rowid,
});
typedef $$LotsTableUpdateCompanionBuilder = LotsCompanion Function({
  Value<String> id,
  Value<String> itemId,
  Value<String> lotNo,
  Value<double> receivedQtyRoll,
  Value<double> measuredLengthM,
  Value<double> usableQtyM,
  Value<String> status,
  Value<String> receivedAt,
  Value<int> rowid,
});

final class $$LotsTableReferences
    extends BaseReferences<_$AppDatabase, $LotsTable, LotRow> {
  $$LotsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ItemsTable _itemIdTable(_$AppDatabase db) =>
      db.items.createAlias($_aliasNameGenerator(db.lots.itemId, db.items.id));

  $$ItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$ItemsTableTableManager($_db, $_db.items)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$LotsTableFilterComposer extends Composer<_$AppDatabase, $LotsTable> {
  $$LotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lotNo => $composableBuilder(
      column: $table.lotNo, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get receivedQtyRoll => $composableBuilder(
      column: $table.receivedQtyRoll,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get measuredLengthM => $composableBuilder(
      column: $table.measuredLengthM,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get usableQtyM => $composableBuilder(
      column: $table.usableQtyM, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => ColumnFilters(column));

  $$ItemsTableFilterComposer get itemId {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.itemId,
        referencedTable: $db.items,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItemsTableFilterComposer(
              $db: $db,
              $table: $db.items,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$LotsTableOrderingComposer extends Composer<_$AppDatabase, $LotsTable> {
  $$LotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lotNo => $composableBuilder(
      column: $table.lotNo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get receivedQtyRoll => $composableBuilder(
      column: $table.receivedQtyRoll,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get measuredLengthM => $composableBuilder(
      column: $table.measuredLengthM,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get usableQtyM => $composableBuilder(
      column: $table.usableQtyM, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => ColumnOrderings(column));

  $$ItemsTableOrderingComposer get itemId {
    final $$ItemsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.itemId,
        referencedTable: $db.items,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItemsTableOrderingComposer(
              $db: $db,
              $table: $db.items,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$LotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LotsTable> {
  $$LotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get lotNo =>
      $composableBuilder(column: $table.lotNo, builder: (column) => column);

  GeneratedColumn<double> get receivedQtyRoll => $composableBuilder(
      column: $table.receivedQtyRoll, builder: (column) => column);

  GeneratedColumn<double> get measuredLengthM => $composableBuilder(
      column: $table.measuredLengthM, builder: (column) => column);

  GeneratedColumn<double> get usableQtyM => $composableBuilder(
      column: $table.usableQtyM, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => column);

  $$ItemsTableAnnotationComposer get itemId {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.itemId,
        referencedTable: $db.items,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItemsTableAnnotationComposer(
              $db: $db,
              $table: $db.items,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$LotsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LotsTable,
    LotRow,
    $$LotsTableFilterComposer,
    $$LotsTableOrderingComposer,
    $$LotsTableAnnotationComposer,
    $$LotsTableCreateCompanionBuilder,
    $$LotsTableUpdateCompanionBuilder,
    (LotRow, $$LotsTableReferences),
    LotRow,
    PrefetchHooks Function({bool itemId})> {
  $$LotsTableTableManager(_$AppDatabase db, $LotsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> itemId = const Value.absent(),
            Value<String> lotNo = const Value.absent(),
            Value<double> receivedQtyRoll = const Value.absent(),
            Value<double> measuredLengthM = const Value.absent(),
            Value<double> usableQtyM = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> receivedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LotsCompanion(
            id: id,
            itemId: itemId,
            lotNo: lotNo,
            receivedQtyRoll: receivedQtyRoll,
            measuredLengthM: measuredLengthM,
            usableQtyM: usableQtyM,
            status: status,
            receivedAt: receivedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String itemId,
            required String lotNo,
            required double receivedQtyRoll,
            required double measuredLengthM,
            required double usableQtyM,
            Value<String> status = const Value.absent(),
            required String receivedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              LotsCompanion.insert(
            id: id,
            itemId: itemId,
            lotNo: lotNo,
            receivedQtyRoll: receivedQtyRoll,
            measuredLengthM: measuredLengthM,
            usableQtyM: usableQtyM,
            status: status,
            receivedAt: receivedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$LotsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({itemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                      dynamic>>(state) {
                if (itemId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.itemId,
                    referencedTable: $$LotsTableReferences._itemIdTable(db),
                    referencedColumn: $$LotsTableReferences._itemIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$LotsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LotsTable,
    LotRow,
    $$LotsTableFilterComposer,
    $$LotsTableOrderingComposer,
    $$LotsTableAnnotationComposer,
    $$LotsTableCreateCompanionBuilder,
    $$LotsTableUpdateCompanionBuilder,
    (LotRow, $$LotsTableReferences),
    LotRow,
    PrefetchHooks Function({bool itemId})>;
typedef $$QuickActionOrdersTableCreateCompanionBuilder
    = QuickActionOrdersCompanion Function({
  required String action,
  required int orderIndex,
  Value<int> rowid,
});
typedef $$QuickActionOrdersTableUpdateCompanionBuilder
    = QuickActionOrdersCompanion Function({
  Value<String> action,
  Value<int> orderIndex,
  Value<int> rowid,
});

class $$QuickActionOrdersTableFilterComposer
    extends Composer<_$AppDatabase, $QuickActionOrdersTable> {
  $$QuickActionOrdersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get orderIndex => $composableBuilder(
      column: $table.orderIndex, builder: (column) => ColumnFilters(column));
}

class $$QuickActionOrdersTableOrderingComposer
    extends Composer<_$AppDatabase, $QuickActionOrdersTable> {
  $$QuickActionOrdersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get orderIndex => $composableBuilder(
      column: $table.orderIndex, builder: (column) => ColumnOrderings(column));
}

class $$QuickActionOrdersTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuickActionOrdersTable> {
  $$QuickActionOrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
      column: $table.orderIndex, builder: (column) => column);
}

class $$QuickActionOrdersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $QuickActionOrdersTable,
    QuickActionOrder,
    $$QuickActionOrdersTableFilterComposer,
    $$QuickActionOrdersTableOrderingComposer,
    $$QuickActionOrdersTableAnnotationComposer,
    $$QuickActionOrdersTableCreateCompanionBuilder,
    $$QuickActionOrdersTableUpdateCompanionBuilder,
    (
      QuickActionOrder,
      BaseReferences<_$AppDatabase, $QuickActionOrdersTable, QuickActionOrder>
    ),
    QuickActionOrder,
    PrefetchHooks Function()> {
  $$QuickActionOrdersTableTableManager(
      _$AppDatabase db, $QuickActionOrdersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuickActionOrdersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuickActionOrdersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuickActionOrdersTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> action = const Value.absent(),
            Value<int> orderIndex = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              QuickActionOrdersCompanion(
            action: action,
            orderIndex: orderIndex,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String action,
            required int orderIndex,
            Value<int> rowid = const Value.absent(),
          }) =>
              QuickActionOrdersCompanion.insert(
            action: action,
            orderIndex: orderIndex,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$QuickActionOrdersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $QuickActionOrdersTable,
    QuickActionOrder,
    $$QuickActionOrdersTableFilterComposer,
    $$QuickActionOrdersTableOrderingComposer,
    $$QuickActionOrdersTableAnnotationComposer,
    $$QuickActionOrdersTableCreateCompanionBuilder,
    $$QuickActionOrdersTableUpdateCompanionBuilder,
    (
      QuickActionOrder,
      BaseReferences<_$AppDatabase, $QuickActionOrdersTable, QuickActionOrder>
    ),
    QuickActionOrder,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ItemsTableTableManager get items =>
      $$ItemsTableTableManager(_db, _db.items);
  $$FoldersTableTableManager get folders =>
      $$FoldersTableTableManager(_db, _db.folders);
  $$ItemPathsTableTableManager get itemPaths =>
      $$ItemPathsTableTableManager(_db, _db.itemPaths);
  $$TxnsTableTableManager get txns => $$TxnsTableTableManager(_db, _db.txns);
  $$BomRowsTableTableManager get bomRows =>
      $$BomRowsTableTableManager(_db, _db.bomRows);
  $$OrdersTableTableManager get orders =>
      $$OrdersTableTableManager(_db, _db.orders);
  $$OrderLinesTableTableManager get orderLines =>
      $$OrderLinesTableTableManager(_db, _db.orderLines);
  $$WorksTableTableManager get works =>
      $$WorksTableTableManager(_db, _db.works);
  $$PurchaseOrdersTableTableManager get purchaseOrders =>
      $$PurchaseOrdersTableTableManager(_db, _db.purchaseOrders);
  $$PurchaseLinesTableTableManager get purchaseLines =>
      $$PurchaseLinesTableTableManager(_db, _db.purchaseLines);
  $$SuppliersTableTableManager get suppliers =>
      $$SuppliersTableTableManager(_db, _db.suppliers);
  $$LotsTableTableManager get lots => $$LotsTableTableManager(_db, _db.lots);
  $$QuickActionOrdersTableTableManager get quickActionOrders =>
      $$QuickActionOrdersTableTableManager(_db, _db.quickActionOrders);
}
