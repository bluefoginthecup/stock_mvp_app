// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class L10nEn extends L10n {
  L10nEn([String locale = 'en']) : super(locale);

  @override
  String adjust_current_qty(int qty, int minQty) {
    return 'Current qty: $qty (min $minQty)';
  }

  @override
  String get adjust_delta_hint => 'Change quantity (+in / -out)';

  @override
  String get app_title => 'Inventory';

  @override
  String get btn_add => 'Add';

  @override
  String get btn_apply => 'Apply';

  @override
  String get btn_save => 'Save';

  @override
  String get common_cancel => 'Cancel';

  @override
  String get common_delete => 'Delete';

  @override
  String get common_ok => 'OK';

  @override
  String get dashboard_below_threshold => 'Below threshold';

  @override
  String get dashboard_goto_details => 'Go to details / filters';

  @override
  String get dashboard_orders => 'Order Management';

  @override
  String get dashboard_purchases => 'Purchase Planning';

  @override
  String get dashboard_stock => 'Stock Management';

  @override
  String get dashboard_summary => 'Summary';

  @override
  String get dashboard_title => 'Dashboard';

  @override
  String get dashboard_total_items => 'Total items';

  @override
  String get dashboard_txns => 'Transaction Log';

  @override
  String get dashboard_works => 'Work Planning';

  @override
  String get empty_finished_items => 'No finished products. Please add items first.';

  @override
  String get field_created_at => 'Created At';

  @override
  String get field_customer => 'Customer';

  @override
  String get field_folder_hint => 'Folder (finished/semi/raw/sub)';

  @override
  String get field_initial_qty => 'Initial qty';

  @override
  String get field_item => 'Item';

  @override
  String get field_memo => '메모';

  @override
  String get field_memo_optional => 'Memo (optional)';

  @override
  String get field_name => 'Name';

  @override
  String get field_qty => 'Qty';

  @override
  String get field_sku => 'SKU';

  @override
  String get field_status_label => 'Status:';

  @override
  String get field_subfolder_optional => 'Subfolder (optional)';

  @override
  String get field_threshold => 'Threshold';

  @override
  String get field_unit_hint => 'Unit (EA/SET/ROLL, etc.)';

  @override
  String get item_not_found => '(Deleted or not found)';

  @override
  String get msg_operation_failed => 'Operation failed';

  @override
  String get msg_status_changed => 'Status updated.';

  @override
  String get order_form_title => 'Edit Order';

  @override
  String order_line_qty(int qty) {
    return 'Qty: $qty';
  }

  @override
  String get order_list_empty_hint => 'No orders. Tap + to add.';

  @override
  String get order_list_title => 'Order List';

  @override
  String order_row_customer_qty(String customer, int totalQty) {
    return '$customer (${totalQty}ea)';
  }

  @override
  String order_row_date_status(String date, String status) {
    return '$date • $status';
  }

  @override
  String get order_saved_and_planned => 'Saved and auto-planned shortages.';

  @override
  String get purchase_action_order => 'Order';

  @override
  String get purchase_action_receive => 'Receive';

  @override
  String get purchase_already_received => 'Already received';

  @override
  String purchase_detail_id(String id) {
    return 'ID: $id';
  }

  @override
  String purchase_detail_item(String itemId) {
    return 'Purchase item: $itemId';
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
  String get purchase_detail_title => 'Purchase Detail';

  @override
  String purchase_detail_vendor(String vendorId) {
    return 'Vendor: $vendorId';
  }

  @override
  String get purchase_list_empty => 'No purchases.';

  @override
  String get purchase_list_title => 'Purchase List';

  @override
  String purchase_row_item_qty(String itemId, int qty) {
    return '$itemId  x$qty';
  }

  @override
  String purchase_row_status_note(String status, String note) {
    return '$status • $note';
  }

  @override
  String get purchase_status_canceled => 'Canceled';

  @override
  String get purchase_status_done => 'Done';

  @override
  String get purchase_status_in_progress => 'In progress';

  @override
  String get purchase_status_ordered => 'Ordered';

  @override
  String get purchase_status_planned => 'Planned';

  @override
  String get purchase_status_received => 'Received';

  @override
  String get purchases_list_empty => 'No purchase plans.';

  @override
  String get purchases_list_title => 'Purchase Planning';

  @override
  String get qty_decrease => 'Decrease quantity';

  @override
  String get qty_increase => 'Increase quantity';

  @override
  String get search_name_code_hint => 'Search name/code';

  @override
  String get section_order_items => 'Order items';

  @override
  String get settings_language_english => 'English';

  @override
  String get settings_language_korean => '한국어';

  @override
  String get settings_language_spanish => 'Español';

  @override
  String get settings_language_system => 'System Default';

  @override
  String get settings_language_title => 'Language Settings';

  @override
  String get stock_list_empty_hint => 'No stock items. Tap + to add.';

  @override
  String get stock_list_title => 'Stock List';

  @override
  String get stock_new_item_title => 'New Item';

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
    return 'Customer $customer';
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
  String get txns_empty => 'No records.';

  @override
  String get txns_list_title => 'Transaction Log';

  @override
  String work_detail_item_qty(String itemName, int qty) {
    return '$itemName  x$qty';
  }

  @override
  String get work_detail_title => 'Work Detail';

  @override
  String get work_list_empty => 'No works.';

  @override
  String get work_list_title => 'Work List';

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
    return 'Customer $customer';
  }

  @override
  String work_row_item_short(String itemShortId) {
    return 'item $itemShortId';
  }

  @override
  String get work_status_planned => 'Planned';

  @override
  String get work_status_in_progress => 'In progress';

  @override
  String get work_status_done => 'Done';

  @override
  String get work_status_canceled => 'Canceled';

  @override
  String work_row_item_fallback(String itemShortId) {
    return 'item $itemShortId';
  }

  @override
  String get label_customer => 'Customer';

  @override
  String get label_order_no => 'Order No.';

  @override
  String get label_item_id => 'Item ID';

  @override
  String get label_created_at => 'Created At';

  @override
  String get work_btn_start => 'Start Work';

  @override
  String get work_btn_complete => 'Complete';

  @override
  String get work_btn_already_done => 'Already done';

  @override
  String get work_btn_canceled => 'Canceled';
}
