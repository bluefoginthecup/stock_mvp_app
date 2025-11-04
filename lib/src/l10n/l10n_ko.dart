// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class L10nKo extends L10n {
  L10nKo([String locale = 'ko']) : super(locale);

  @override
  String get adjust_set_quantity_title => '수량변경';

  @override
  String get hint_longpress_to_edit_qty => '꾹 눌러 수량변경';

  @override
  String adjust_current_qty(int qty, int minQty) {
    return '현재 수량: $qty (min $minQty)';
  }

  @override
  String get adjust_delta_hint => '변경 수량 (+입고 / -출고)';

  @override
  String get app_title => '재고관리';

  @override
  String get btn_add => '추가';

  @override
  String get btn_apply => '적용';

  @override
  String get btn_save => '저장';

  @override
  String get common_cancel => 'Cancel';

  @override
  String get common_delete => '삭제';

  @override
  String get common_ok => '확인';

  @override
  String get common_error => '에러';

  @override
  String get common_warning => '경고';

  @override
  String get common_continue => '계속';

  @override
  String get dashboard_below_threshold => '임계치 이하';

  @override
  String get dashboard_goto_details => '상세 보기 / 필터로 이동';

  @override
  String get dashboard_orders => '주문 관리';

  @override
  String get dashboard_purchases => '발주 계획';

  @override
  String get dashboard_stock => '재고 관리';

  @override
  String get dashboard_summary => '요약';

  @override
  String get dashboard_title => '대시보드';

  @override
  String get dashboard_total_items => '전체 품목';

  @override
  String get dashboard_txns => '입·출고 기록';

  @override
  String get dashboard_works => '작업 계획';

  @override
  String get empty_finished_items => '등록된 완제품이 없습니다. 먼저 품목을 추가하세요.';

  @override
  String get field_created_at => '생성일';

  @override
  String get field_customer => '고객명';

  @override
  String get field_folder_hint => '폴더(finished/semi/raw/sub)';

  @override
  String get field_initial_qty => '초기수량';

  @override
  String get field_item => '품목';

  @override
  String get field_memo => '메모';

  @override
  String get field_memo_optional => '메모(선택)';

  @override
  String get field_name => '이름';

  @override
  String get field_qty => '수량';

  @override
  String get field_sku => '코드(SKU)';

  @override
  String get field_status_label => '상태:';

  @override
  String get field_subfolder_optional => '서브폴더(선택)';

  @override
  String get field_threshold => '임계치';

  @override
  String get field_unit_hint => '단위(EA/SET/ROLL 등)';

  @override
  String get item_not_found => '(삭제되었거나 찾을 수 없음)';

  @override
  String get item_loading_or_missing => '품목 불러오는 중...';

  @override
  String get msg_operation_failed => '작업을 완료할 수 없습니다.';

  @override
  String get msg_status_changed => '상태가 변경되었습니다.';

  @override
  String get order_form_title => '주문 편집';

  @override
  String order_line_qty(int qty) {
    return '수량: $qty';
  }

  @override
  String get order_list_empty_hint => '주문이 없습니다. + 버튼으로 추가하세요.';

  @override
  String get order_list_title => '주문 목록';

  @override
  String order_row_customer_qty(String customer, int totalQty) {
    return '$customer (${totalQty}ea)';
  }

  @override
  String order_row_date_status(String date, String status) {
    return '$date • $status';
  }

  @override
  String get order_saved_and_planned => '저장 + 부족분 자동 계획 생성 완료';

  @override
  String get purchase_action_order => 'Order';

  @override
  String get purchase_action_receive => 'Receive';

  @override
  String get purchase_already_received => '입고완료됨';

  @override
  String purchase_detail_id(String id) {
    return 'ID: $id';
  }

  @override
  String purchase_detail_item(String itemId) {
    return '발주 품목: $itemId';
  }

  @override
  String purchase_detail_note(String note) {
    return 'Note: $note';
  }

  @override
  String purchase_detail_qty(int qty) {
    return 'Qty: $qty';
  }

  @override
  String get purchase_detail_status_label => 'Status:';

  @override
  String get purchase_detail_title => '발주 상세';

  @override
  String purchase_detail_vendor(String vendorId) {
    return 'Vendor: $vendorId';
  }

  @override
  String get purchase_list_empty => '발주가 없습니다.';

  @override
  String get purchase_list_title => '발주 목록';

  @override
  String purchase_row_item_qty(String itemId, int qty) {
    return '$itemId  x$qty';
  }

  @override
  String purchase_row_status_note(String status, String note) {
    return '$status • $note';
  }

  @override
  String get purchase_status_canceled => '취소';

  @override
  String get purchase_status_done => '완료';

  @override
  String get purchase_status_in_progress => '진행중';

  @override
  String get purchase_status_ordered => '발주';

  @override
  String get purchase_status_planned => '계획';

  @override
  String get purchase_status_received => '입고완료';

  @override
  String get purchases_list_empty => '발주 계획이 없습니다.';

  @override
  String get purchases_list_title => '발주 계획';

  @override
  String get qty_decrease => '수량 줄이기';

  @override
  String get qty_increase => '수량 늘리기';

  @override
  String get search_name_code_hint => '이름/코드 검색';

  @override
  String get section_order_items => '주문 품목';

  @override
  String get settings_language_english => 'English';

  @override
  String get settings_language_korean => '한국어';

  @override
  String get settings_language_spanish => 'Español';

  @override
  String get settings_language_system => '시스템 기본';

  @override
  String get settings_language_title => '언어설정';

  @override
  String get common_stock_in => '입고';

  @override
  String get common_stock_out => '출고';

  @override
  String get label_in_qty => '입고 수량';

  @override
  String get label_out_qty => '출고 수량';

  @override
  String get validate_positive_number => '0보다 큰 숫자를 입력하세요';

  @override
  String get label_in_unit => '입고 단위';

  @override
  String get label_out_unit => '출고 단위';

  @override
  String label_conversion_rate(String unitIn, String unitOut) {
    return '$unitIn → $unitOut 환산비율';
  }

  @override
  String get stock_list_empty_hint => '재고가 없습니다. +로 추가하세요.';

  @override
  String get stock_list_title => '재고 목록';

  @override
  String get stock_new_item_title => '새 품목';

  @override
  String stock_row_min_qty(int minQty) {
    return 'min $minQty';
  }

  @override
  String stock_row_sku_folder_subfolder(String sku, String folder, String subfolder) {
    return '$sku • $folder$subfolder';
  }

  @override
  String get tooltip_delete_line => '라인 삭제';

  @override
  String txn_row_customer(String customer) {
    return '주문자 $customer';
  }

  @override
  String txn_row_item_short(String itemShortId) {
    return 'item $itemShortId';
  }

  @override
  String txn_row_ref_short(String refShortId) {
    return 'ref $refShortId';
  }

  @override
  String get txns_empty => '기록이 없습니다.';

  @override
  String get txns_list_title => '입·출고 기록';

  @override
  String work_detail_item_qty(String itemName, int qty) {
    return '$itemName  x$qty';
  }

  @override
  String get work_detail_title => '작업 상세';

  @override
  String get work_list_empty => '작업 계획이 없습니다.';

  @override
  String get work_list_title => '작업 목록';

  @override
  String get work_action_start => 'Start';

  @override
  String get work_action_done => 'Done';

  @override
  String work_row_item_qty(String itemName, int qty) {
    return '$itemName   x$qty';
  }

  @override
  String work_row_order_short(String orderShortId) {
    return 'order $orderShortId';
  }

  @override
  String work_row_customer(String customer) {
    return '주문자 $customer';
  }

  @override
  String work_row_item_short(String itemShortId) {
    return 'item $itemShortId';
  }

  @override
  String get work_status_planned => '계획';

  @override
  String get work_status_in_progress => '진행중';

  @override
  String get work_status_done => '완료';

  @override
  String get work_status_canceled => '취소';

  @override
  String work_row_item_fallback(String itemShortId) {
    return '아이템 $itemShortId';
  }

  @override
  String get label_customer => '주문자';

  @override
  String get label_order_no => '주문번호';

  @override
  String get label_item_id => '아이템 ID';

  @override
  String get label_created_at => '생성일';

  @override
  String get work_btn_start => '작업 시작';

  @override
  String get work_btn_complete => '완료 처리';

  @override
  String get work_btn_already_done => '이미 완료됨';

  @override
  String get work_btn_canceled => '취소됨';

  @override
  String get stock_item_detail_title => '아이템 상세';

  @override
  String get txn_list_empty_hint => '입출고 내역이 없습니다.';

  @override
  String get txn_recent_button => '최근 입출고 내역';

  @override
  String get common_stock => '재고';

  @override
  String get item_unit => '단위';

  @override
  String get bom_edit_section_title => 'BOM 편집';

  @override
  String get bom_edit_finished => 'Finished BOM 편집';

  @override
  String get bom_edit_semi => 'Semi BOM 편집';

  @override
  String get bom_edit_unknown_type_hint => '유형을 확정할 수 없어 두 버튼을 모두 표시합니다.';
}
