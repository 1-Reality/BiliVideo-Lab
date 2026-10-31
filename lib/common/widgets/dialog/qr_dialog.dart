import 'package:material_ui/material_ui.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

/// 统一的单张二维码弹窗，所有"二维码分享"入口都走这里
Future<void> showQrDialog(
  BuildContext context, {
  required String data,
  String? title,
}) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260, maxHeight: 260),
            child: PrettyQrView.data(
              data: data,
              decoration: const PrettyQrDecoration(
                shape: PrettyQrSquaresSymbol(),
                background: Colors.white,
                quietZone: PrettyQrQuietZone.modules(4),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
