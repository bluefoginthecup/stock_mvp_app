// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class L10nEs extends L10n {
  L10nEs([String locale = 'es']) : super(locale);

  @override
  String adjust_current_qty(int qty, int minQty) {
    return 'Cantidad actual: $qty (mín $minQty)';
  }

  @override
  String get adjust_delta_hint => 'Cambiar cantidad (+entrada / -salida)';

  @override
  String get app_title => 'Inventario';

  @override
  String get btn_add => 'Agregar';

  @override
  String get btn_apply => 'Aplicar';

  @override
  String get btn_save => 'Guardar';

  @override
  String get common_cancel => 'Cancelar';

  @override
  String get common_delete => 'Eliminar';

  @override
  String get common_ok => 'Aceptar';

  @override
  String get dashboard_below_threshold => 'Por debajo del umbral';

  @override
  String get dashboard_goto_details => 'Ir a detalles / filtros';

  @override
  String get dashboard_orders => 'Gestión de pedidos';

  @override
  String get dashboard_purchases => 'Planificación de compras';

  @override
  String get dashboard_stock => 'Gestión de inventario';

  @override
  String get dashboard_summary => 'Resumen';

  @override
  String get dashboard_title => 'Panel';

  @override
  String get dashboard_total_items => 'Artículos totales';

  @override
  String get dashboard_txns => 'Registro de movimientos';

  @override
  String get dashboard_works => 'Planificación de trabajos';

  @override
  String get empty_finished_items => 'No hay productos terminados. Agrega artículos primero.';

  @override
  String get field_created_at => 'Fecha de creación';

  @override
  String get field_customer => 'Cliente';

  @override
  String get field_folder_hint => 'Carpeta (finished/semi/raw/sub)';

  @override
  String get field_initial_qty => 'Cantidad inicial';

  @override
  String get field_item => 'Artículo';

  @override
  String get field_memo => '메모';

  @override
  String get field_memo_optional => 'Nota (opcional)';

  @override
  String get field_name => 'Nombre';

  @override
  String get field_qty => 'Cant.';

  @override
  String get field_sku => 'SKU';

  @override
  String get field_status_label => 'Estado:';

  @override
  String get field_subfolder_optional => 'Subcarpeta (opcional)';

  @override
  String get field_threshold => 'Umbral';

  @override
  String get field_unit_hint => 'Unidad (EA/SET/ROLL, etc.)';

  @override
  String get item_not_found => '(Eliminado o no encontrado)';

  @override
  String get item_loading_or_missing => 'Cargando artículos...';

  @override
  String get msg_operation_failed => 'No se pudo completar la operación.';

  @override
  String get msg_status_changed => 'Estado actualizado.';

  @override
  String get order_form_title => 'Editar pedido';

  @override
  String order_line_qty(int qty) {
    return 'Cant.: $qty';
  }

  @override
  String get order_list_empty_hint => 'No hay pedidos. Toca + para agregar.';

  @override
  String get order_list_title => 'Lista de pedidos';

  @override
  String order_row_customer_qty(String customer, int totalQty) {
    return '$customer (${totalQty}ud)';
  }

  @override
  String order_row_date_status(String date, String status) {
    return '$date • $status';
  }

  @override
  String get order_saved_and_planned => 'Guardado y se planificaron faltantes automáticamente.';

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
  String get purchase_detail_status_label => 'Estado:';

  @override
  String get purchase_detail_title => 'Purchase Detail';

  @override
  String purchase_detail_vendor(String vendorId) {
    return 'Vendor: $vendorId';
  }

  @override
  String get purchase_list_empty => 'No hay órdenes de compra.';

  @override
  String get purchase_list_title => 'Lista de órdenes de compra';

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
  String get purchase_status_done => 'Completado';

  @override
  String get purchase_status_in_progress => 'En curso';

  @override
  String get purchase_status_ordered => 'Ordered';

  @override
  String get purchase_status_planned => 'Planned';

  @override
  String get purchase_status_received => 'Received';

  @override
  String get purchases_list_empty => 'No hay planes de compra.';

  @override
  String get purchases_list_title => 'Planificación de compras';

  @override
  String get qty_decrease => 'Disminuir cantidad';

  @override
  String get qty_increase => 'Aumentar cantidad';

  @override
  String get search_name_code_hint => 'Buscar nombre/código';

  @override
  String get section_order_items => 'Artículos del pedido';

  @override
  String get settings_language_english => 'English';

  @override
  String get settings_language_korean => '한국어';

  @override
  String get settings_language_spanish => 'Español';

  @override
  String get settings_language_system => 'Predeterminado del sistema';

  @override
  String get settings_language_title => 'Configuración de idioma';

  @override
  String get stock_list_empty_hint => 'Sin artículos. Toca + para agregar.';

  @override
  String get stock_list_title => 'Lista de inventario';

  @override
  String get stock_new_item_title => 'Nuevo artículo';

  @override
  String stock_row_min_qty(int minQty) {
    return 'mín $minQty';
  }

  @override
  String stock_row_sku_folder_subfolder(String sku, String folder, String subfolder) {
    return '$sku • $folder$subfolder';
  }

  @override
  String get tooltip_delete_line => '라인 삭제';

  @override
  String txn_row_customer(String customer) {
    return 'Cliente $customer';
  }

  @override
  String txn_row_item_short(String itemShortId) {
    return 'artículo $itemShortId';
  }

  @override
  String txn_row_ref_short(String refShortId) {
    return 'ref $refShortId';
  }

  @override
  String get txns_empty => 'No hay registros.';

  @override
  String get txns_list_title => 'Registro de movimientos';

  @override
  String work_detail_item_qty(String itemName, int qty) {
    return '$itemName  x$qty';
  }

  @override
  String get work_detail_title => 'Detalle del trabajo';

  @override
  String get work_list_empty => 'No hay trabajos.';

  @override
  String get work_list_title => 'Lista de trabajos';

  @override
  String get work_action_start => 'Iniciar';

  @override
  String get work_action_done => 'Terminar';

  @override
  String work_row_item_qty(String itemName, int qty) {
    return '$itemName   x$qty';
  }

  @override
  String work_row_order_short(String orderShortId) {
    return 'pedido $orderShortId';
  }

  @override
  String work_row_customer(String customer) {
    return 'Cliente $customer';
  }

  @override
  String work_row_item_short(String itemShortId) {
    return 'artículo $itemShortId';
  }

  @override
  String get work_status_planned => 'Planificado';

  @override
  String get work_status_in_progress => 'En curso';

  @override
  String get work_status_done => 'Completado';

  @override
  String get work_status_canceled => 'Cancelado';

  @override
  String work_row_item_fallback(String itemShortId) {
    return 'artículo $itemShortId';
  }

  @override
  String get label_customer => 'Cliente';

  @override
  String get label_order_no => 'N.º de pedido';

  @override
  String get label_item_id => 'ID del artículo';

  @override
  String get label_created_at => 'Creado el';

  @override
  String get work_btn_start => 'Iniciar';

  @override
  String get work_btn_complete => 'Finalizar';

  @override
  String get work_btn_already_done => 'Ya completado';

  @override
  String get work_btn_canceled => 'Cancelado';

  @override
  String get stock_item_detail_title => 'Detalle del artículo';

  @override
  String get txn_list_empty_hint => 'No hay registros de entrada o salida.';

  @override
  String get txn_recent_button => 'Movimientos recientes';

  @override
  String get common_stock => 'Existencias';

  @override
  String get item_unit => 'Unidad';

  @override
  String get bom_edit_section_title => 'Edición de BOM';

  @override
  String get bom_edit_finished => 'Editar BOM de producto terminado';

  @override
  String get bom_edit_semi => 'Editar BOM de semielaborado';

  @override
  String get bom_edit_unknown_type_hint => 'El tipo de artículo no está claro, por lo que se muestran ambos botones.';
}
