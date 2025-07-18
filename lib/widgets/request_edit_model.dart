import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class RequestEditModal extends StatefulWidget {
  final String type; // 'sale' or 'order'
  final int itemId;
  final String requestedBy;

  const RequestEditModal({
    super.key,
    required this.type,
    required this.itemId,
    required this.requestedBy,
  });

  @override
  State<RequestEditModal> createState() => _RequestEditModalState();
}

class _RequestEditModalState extends State<RequestEditModal> {
  final TextEditingController reasonController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context, listen: false);

    return AlertDialog(
      title: Text('Request Edit Access'),
      content: TextField(
        controller: reasonController,
        decoration: InputDecoration(labelText: 'Reason for edit'),
      ),
      actions: [
        TextButton(
          child: Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          child: Text('Submit'),
          onPressed: () {
            appData.addEditRequest(
              type: widget.type,
              itemId: widget.itemId,
              reason: reasonController.text,
              requestedBy: widget.requestedBy,
            );
            Navigator.pop(context);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Edit request submitted!')));
          },
        ),
      ],
    );
  }
}
