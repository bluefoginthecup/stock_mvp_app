import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'l10n_en.dart';
import 'l10n_es.dart';
import 'l10n_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('ko')
  ];

  /// No description provided for @adjust_set_quantity_title.
  ///
  /// In ko, this message translates to:
  /// **'수량변경'**
  String get adjust_set_quantity_title;

  /// No description provided for @hint_longpress_to_edit_qty.
  ///
  /// In ko, this message translates to:
  /// **'꾹 눌러 수량변경'**
  String get hint_longpress_to_edit_qty;

  /// No description provided for @adjust_current_qty.
  ///
  /// In ko, this message translates to:
  /// **'현재 수량: {qty} (min {minQty})'**
  String adjust_current_qty(int qty, int minQty);

  /// No description provided for @adjust_delta_hint.
  ///
  /// In ko, this message translates to:
  /// **'변경 수량 (+입고 / -출고)'**
  String get adjust_delta_hint;

  /// No description provided for @app_title.
  ///
  /// In ko, this message translates to:
  /// **'재고관리'**
  String get app_title;

  /// No description provided for @btn_add.
  ///
  /// In ko, this message translates to:
  /// **'추가'**
  String get btn_add;

  /// No description provided for @btn_apply.
  ///
  /// In ko, this message translates to:
  /// **'적용'**
  String get btn_apply;

  /// No description provided for @btn_save.
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get btn_save;

  /// No description provided for @common_cancel.
  ///
  /// In ko, this message translates to:
  /// **'Cancel'**
  String get common_cancel;

  /// No description provided for @common_delete.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get common_delete;

  /// No description provided for @common_ok.
  ///
  /// In ko, this message translates to:
  /// **'확인'**
  String get common_ok;

  /// No description provided for @common_error.
  ///
  /// In ko, this message translates to:
  /// **'에러'**
  String get common_error;

  /// No description provided for @dashboard_below_threshold.
  ///
  /// In ko, this message translates to:
  /// **'임계치 이하'**
  String get dashboard_below_threshold;

  /// No description provided for @dashboard_goto_details.
  ///
  /// In ko, this message translates to:
  /// **'상세 보기 / 필터로 이동'**
  String get dashboard_goto_details;

  /// No description provided for @dashboard_orders.
  ///
  /// In ko, this message translates to:
  /// **'주문 관리'**
  String get dashboard_orders;

  /// No description provided for @dashboard_purchases.
  ///
  /// In ko, this message translates to:
  /// **'발주 계획'**
  String get dashboard_purchases;

  /// No description provided for @dashboard_stock.
  ///
  /// In ko, this message translates to:
  /// **'재고 관리'**
  String get dashboard_stock;

  /// No description provided for @dashboard_summary.
  ///
  /// In ko, this message translates to:
  /// **'요약'**
  String get dashboard_summary;

  /// No description provided for @dashboard_title.
  ///
  /// In ko, this message translates to:
  /// **'대시보드'**
  String get dashboard_title;

  /// No description provided for @dashboard_total_items.
  ///
  /// In ko, this message translates to:
  /// **'전체 품목'**
  String get dashboard_total_items;

  /// No description provided for @dashboard_txns.
  ///
  /// In ko, this message translates to:
  /// **'입·출고 기록'**
  String get dashboard_txns;

  /// No description provided for @dashboard_works.
  ///
  /// In ko, this message translates to:
  /// **'작업 계획'**
  String get dashboard_works;

  /// No description provided for @empty_finished_items.
  ///
  /// In ko, this message translates to:
  /// **'등록된 완제품이 없습니다. 먼저 품목을 추가하세요.'**
  String get empty_finished_items;

  /// No description provided for @field_created_at.
  ///
  /// In ko, this message translates to:
  /// **'생성일'**
  String get field_created_at;

  /// No description provided for @field_customer.
  ///
  /// In ko, this message translates to:
  /// **'고객명'**
  String get field_customer;

  /// No description provided for @field_folder_hint.
  ///
  /// In ko, this message translates to:
  /// **'폴더(finished/semi/raw/sub)'**
  String get field_folder_hint;

  /// No description provided for @field_initial_qty.
  ///
  /// In ko, this message translates to:
  /// **'초기수량'**
  String get field_initial_qty;

  /// No description provided for @field_item.
  ///
  /// In ko, this message translates to:
  /// **'품목'**
  String get field_item;

  /// No description provided for @field_memo.
  ///
  /// In ko, this message translates to:
  /// **'메모'**
  String get field_memo;

  /// No description provided for @field_memo_optional.
  ///
  /// In ko, this message translates to:
  /// **'메모(선택)'**
  String get field_memo_optional;

  /// No description provided for @field_name.
  ///
  /// In ko, this message translates to:
  /// **'이름'**
  String get field_name;

  /// No description provided for @field_qty.
  ///
  /// In ko, this message translates to:
  /// **'수량'**
  String get field_qty;

  /// No description provided for @field_sku.
  ///
  /// In ko, this message translates to:
  /// **'코드(SKU)'**
  String get field_sku;

  /// No description provided for @field_status_label.
  ///
  /// In ko, this message translates to:
  /// **'상태:'**
  String get field_status_label;

  /// No description provided for @field_subfolder_optional.
  ///
  /// In ko, this message translates to:
  /// **'서브폴더(선택)'**
  String get field_subfolder_optional;

  /// No description provided for @field_threshold.
  ///
  /// In ko, this message translates to:
  /// **'임계치'**
  String get field_threshold;

  /// No description provided for @field_unit_hint.
  ///
  /// In ko, this message translates to:
  /// **'단위(EA/SET/ROLL 등)'**
  String get field_unit_hint;

  /// No description provided for @item_not_found.
  ///
  /// In ko, this message translates to:
  /// **'(삭제되었거나 찾을 수 없음)'**
  String get item_not_found;

  /// No description provided for @item_loading_or_missing.
  ///
  /// In ko, this message translates to:
  /// **'품목 불러오는 중...'**
  String get item_loading_or_missing;

  /// No description provided for @msg_operation_failed.
  ///
  /// In ko, this message translates to:
  /// **'작업을 완료할 수 없습니다.'**
  String get msg_operation_failed;

  /// No description provided for @msg_status_changed.
  ///
  /// In ko, this message translates to:
  /// **'상태가 변경되었습니다.'**
  String get msg_status_changed;

  /// No description provided for @order_form_title.
  ///
  /// In ko, this message translates to:
  /// **'주문 편집'**
  String get order_form_title;

  /// No description provided for @order_line_qty.
  ///
  /// In ko, this message translates to:
  /// **'수량: {qty}'**
  String order_line_qty(int qty);

  /// No description provided for @order_list_empty_hint.
  ///
  /// In ko, this message translates to:
  /// **'주문이 없습니다. + 버튼으로 추가하세요.'**
  String get order_list_empty_hint;

  /// No description provided for @order_list_title.
  ///
  /// In ko, this message translates to:
  /// **'주문 목록'**
  String get order_list_title;

  /// No description provided for @order_row_customer_qty.
  ///
  /// In ko, this message translates to:
  /// **'{customer} ({totalQty}ea)'**
  String order_row_customer_qty(String customer, int totalQty);

  /// No description provided for @order_row_date_status.
  ///
  /// In ko, this message translates to:
  /// **'{date} • {status}'**
  String order_row_date_status(String date, String status);

  /// No description provided for @order_saved_and_planned.
  ///
  /// In ko, this message translates to:
  /// **'저장 + 부족분 자동 계획 생성 완료'**
  String get order_saved_and_planned;

  /// No description provided for @purchase_action_order.
  ///
  /// In ko, this message translates to:
  /// **'Order'**
  String get purchase_action_order;

  /// No description provided for @purchase_action_receive.
  ///
  /// In ko, this message translates to:
  /// **'Receive'**
  String get purchase_action_receive;

  /// No description provided for @purchase_already_received.
  ///
  /// In ko, this message translates to:
  /// **'입고완료됨'**
  String get purchase_already_received;

  /// No description provided for @purchase_detail_id.
  ///
  /// In ko, this message translates to:
  /// **'ID: {id}'**
  String purchase_detail_id(String id);

  /// No description provided for @purchase_detail_item.
  ///
  /// In ko, this message translates to:
  /// **'발주 품목: {itemId}'**
  String purchase_detail_item(String itemId);

  /// No description provided for @purchase_detail_note.
  ///
  /// In ko, this message translates to:
  /// **'Note: {note}'**
  String purchase_detail_note(String note);

  /// No description provided for @purchase_detail_qty.
  ///
  /// In ko, this message translates to:
  /// **'Qty: {qty}'**
  String purchase_detail_qty(int qty);

  /// No description provided for @purchase_detail_status_label.
  ///
  /// In ko, this message translates to:
  /// **'Status:'**
  String get purchase_detail_status_label;

  /// No description provided for @purchase_detail_title.
  ///
  /// In ko, this message translates to:
  /// **'발주 상세'**
  String get purchase_detail_title;

  /// No description provided for @purchase_detail_vendor.
  ///
  /// In ko, this message translates to:
  /// **'Vendor: {vendorId}'**
  String purchase_detail_vendor(String vendorId);

  /// No description provided for @purchase_list_empty.
  ///
  /// In ko, this message translates to:
  /// **'발주가 없습니다.'**
  String get purchase_list_empty;

  /// No description provided for @purchase_list_title.
  ///
  /// In ko, this message translates to:
  /// **'발주 목록'**
  String get purchase_list_title;

  /// No description provided for @purchase_row_item_qty.
  ///
  /// In ko, this message translates to:
  /// **'{itemId}  x{qty}'**
  String purchase_row_item_qty(String itemId, int qty);

  /// No description provided for @purchase_row_status_note.
  ///
  /// In ko, this message translates to:
  /// **'{status} • {note}'**
  String purchase_row_status_note(String status, String note);

  /// No description provided for @purchase_status_canceled.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get purchase_status_canceled;

  /// No description provided for @purchase_status_done.
  ///
  /// In ko, this message translates to:
  /// **'완료'**
  String get purchase_status_done;

  /// No description provided for @purchase_status_in_progress.
  ///
  /// In ko, this message translates to:
  /// **'진행중'**
  String get purchase_status_in_progress;

  /// No description provided for @purchase_status_ordered.
  ///
  /// In ko, this message translates to:
  /// **'발주'**
  String get purchase_status_ordered;

  /// No description provided for @purchase_status_planned.
  ///
  /// In ko, this message translates to:
  /// **'계획'**
  String get purchase_status_planned;

  /// No description provided for @purchase_status_received.
  ///
  /// In ko, this message translates to:
  /// **'입고완료'**
  String get purchase_status_received;

  /// No description provided for @purchases_list_empty.
  ///
  /// In ko, this message translates to:
  /// **'발주 계획이 없습니다.'**
  String get purchases_list_empty;

  /// No description provided for @purchases_list_title.
  ///
  /// In ko, this message translates to:
  /// **'발주 계획'**
  String get purchases_list_title;

  /// No description provided for @qty_decrease.
  ///
  /// In ko, this message translates to:
  /// **'수량 줄이기'**
  String get qty_decrease;

  /// No description provided for @qty_increase.
  ///
  /// In ko, this message translates to:
  /// **'수량 늘리기'**
  String get qty_increase;

  /// No description provided for @search_name_code_hint.
  ///
  /// In ko, this message translates to:
  /// **'이름/코드 검색'**
  String get search_name_code_hint;

  /// No description provided for @section_order_items.
  ///
  /// In ko, this message translates to:
  /// **'주문 품목'**
  String get section_order_items;

  /// No description provided for @settings_language_english.
  ///
  /// In ko, this message translates to:
  /// **'English'**
  String get settings_language_english;

  /// No description provided for @settings_language_korean.
  ///
  /// In ko, this message translates to:
  /// **'한국어'**
  String get settings_language_korean;

  /// No description provided for @settings_language_spanish.
  ///
  /// In ko, this message translates to:
  /// **'Español'**
  String get settings_language_spanish;

  /// No description provided for @settings_language_system.
  ///
  /// In ko, this message translates to:
  /// **'시스템 기본'**
  String get settings_language_system;

  /// No description provided for @settings_language_title.
  ///
  /// In ko, this message translates to:
  /// **'언어설정'**
  String get settings_language_title;

  /// No description provided for @stock_list_empty_hint.
  ///
  /// In ko, this message translates to:
  /// **'재고가 없습니다. +로 추가하세요.'**
  String get stock_list_empty_hint;

  /// No description provided for @stock_list_title.
  ///
  /// In ko, this message translates to:
  /// **'재고 목록'**
  String get stock_list_title;

  /// No description provided for @stock_new_item_title.
  ///
  /// In ko, this message translates to:
  /// **'새 품목'**
  String get stock_new_item_title;

  /// No description provided for @stock_row_min_qty.
  ///
  /// In ko, this message translates to:
  /// **'min {minQty}'**
  String stock_row_min_qty(int minQty);

  /// No description provided for @stock_row_sku_folder_subfolder.
  ///
  /// In ko, this message translates to:
  /// **'{sku} • {folder}{subfolder}'**
  String stock_row_sku_folder_subfolder(String sku, String folder, String subfolder);

  /// No description provided for @tooltip_delete_line.
  ///
  /// In ko, this message translates to:
  /// **'라인 삭제'**
  String get tooltip_delete_line;

  /// No description provided for @txn_row_customer.
  ///
  /// In ko, this message translates to:
  /// **'주문자 {customer}'**
  String txn_row_customer(String customer);

  /// No description provided for @txn_row_item_short.
  ///
  /// In ko, this message translates to:
  /// **'item {itemShortId}'**
  String txn_row_item_short(String itemShortId);

  /// No description provided for @txn_row_ref_short.
  ///
  /// In ko, this message translates to:
  /// **'ref {refShortId}'**
  String txn_row_ref_short(String refShortId);

  /// No description provided for @txns_empty.
  ///
  /// In ko, this message translates to:
  /// **'기록이 없습니다.'**
  String get txns_empty;

  /// No description provided for @txns_list_title.
  ///
  /// In ko, this message translates to:
  /// **'입·출고 기록'**
  String get txns_list_title;

  /// No description provided for @work_detail_item_qty.
  ///
  /// In ko, this message translates to:
  /// **'{itemName}  x{qty}'**
  String work_detail_item_qty(String itemName, int qty);

  /// No description provided for @work_detail_title.
  ///
  /// In ko, this message translates to:
  /// **'작업 상세'**
  String get work_detail_title;

  /// No description provided for @work_list_empty.
  ///
  /// In ko, this message translates to:
  /// **'작업 계획이 없습니다.'**
  String get work_list_empty;

  /// No description provided for @work_list_title.
  ///
  /// In ko, this message translates to:
  /// **'작업 목록'**
  String get work_list_title;

  /// No description provided for @work_action_start.
  ///
  /// In ko, this message translates to:
  /// **'Start'**
  String get work_action_start;

  /// No description provided for @work_action_done.
  ///
  /// In ko, this message translates to:
  /// **'Done'**
  String get work_action_done;

  /// No description provided for @work_row_item_qty.
  ///
  /// In ko, this message translates to:
  /// **'{itemName}   x{qty}'**
  String work_row_item_qty(String itemName, int qty);

  /// No description provided for @work_row_order_short.
  ///
  /// In ko, this message translates to:
  /// **'order {orderShortId}'**
  String work_row_order_short(String orderShortId);

  /// No description provided for @work_row_customer.
  ///
  /// In ko, this message translates to:
  /// **'주문자 {customer}'**
  String work_row_customer(String customer);

  /// No description provided for @work_row_item_short.
  ///
  /// In ko, this message translates to:
  /// **'item {itemShortId}'**
  String work_row_item_short(String itemShortId);

  /// No description provided for @work_status_planned.
  ///
  /// In ko, this message translates to:
  /// **'계획'**
  String get work_status_planned;

  /// No description provided for @work_status_in_progress.
  ///
  /// In ko, this message translates to:
  /// **'진행중'**
  String get work_status_in_progress;

  /// No description provided for @work_status_done.
  ///
  /// In ko, this message translates to:
  /// **'완료'**
  String get work_status_done;

  /// No description provided for @work_status_canceled.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get work_status_canceled;

  /// No description provided for @work_row_item_fallback.
  ///
  /// In ko, this message translates to:
  /// **'아이템 {itemShortId}'**
  String work_row_item_fallback(String itemShortId);

  /// No description provided for @label_customer.
  ///
  /// In ko, this message translates to:
  /// **'주문자'**
  String get label_customer;

  /// No description provided for @label_order_no.
  ///
  /// In ko, this message translates to:
  /// **'주문번호'**
  String get label_order_no;

  /// No description provided for @label_item_id.
  ///
  /// In ko, this message translates to:
  /// **'아이템 ID'**
  String get label_item_id;

  /// No description provided for @label_created_at.
  ///
  /// In ko, this message translates to:
  /// **'생성일'**
  String get label_created_at;

  /// No description provided for @work_btn_start.
  ///
  /// In ko, this message translates to:
  /// **'작업 시작'**
  String get work_btn_start;

  /// No description provided for @work_btn_complete.
  ///
  /// In ko, this message translates to:
  /// **'완료 처리'**
  String get work_btn_complete;

  /// No description provided for @work_btn_already_done.
  ///
  /// In ko, this message translates to:
  /// **'이미 완료됨'**
  String get work_btn_already_done;

  /// No description provided for @work_btn_canceled.
  ///
  /// In ko, this message translates to:
  /// **'취소됨'**
  String get work_btn_canceled;

  /// No description provided for @stock_item_detail_title.
  ///
  /// In ko, this message translates to:
  /// **'아이템 상세'**
  String get stock_item_detail_title;

  /// No description provided for @txn_list_empty_hint.
  ///
  /// In ko, this message translates to:
  /// **'입출고 내역이 없습니다.'**
  String get txn_list_empty_hint;

  /// No description provided for @txn_recent_button.
  ///
  /// In ko, this message translates to:
  /// **'최근 입출고 내역'**
  String get txn_recent_button;

  /// No description provided for @common_stock.
  ///
  /// In ko, this message translates to:
  /// **'재고'**
  String get common_stock;

  /// No description provided for @item_unit.
  ///
  /// In ko, this message translates to:
  /// **'단위'**
  String get item_unit;

  /// No description provided for @bom_edit_section_title.
  ///
  /// In ko, this message translates to:
  /// **'BOM 편집'**
  String get bom_edit_section_title;

  /// No description provided for @bom_edit_finished.
  ///
  /// In ko, this message translates to:
  /// **'Finished BOM 편집'**
  String get bom_edit_finished;

  /// No description provided for @bom_edit_semi.
  ///
  /// In ko, this message translates to:
  /// **'Semi BOM 편집'**
  String get bom_edit_semi;

  /// No description provided for @bom_edit_unknown_type_hint.
  ///
  /// In ko, this message translates to:
  /// **'유형을 확정할 수 없어 두 버튼을 모두 표시합니다.'**
  String get bom_edit_unknown_type_hint;
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'es', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return L10nEn();
    case 'es': return L10nEs();
    case 'ko': return L10nKo();
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
