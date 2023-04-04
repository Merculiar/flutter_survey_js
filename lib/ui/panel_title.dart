import 'package:flutter/material.dart';
import 'package:flutter_survey_js/model/survey.dart' as s;

class PanelTitle extends StatelessWidget {
  final s.PanelBase panel;
  final VoidCallback? onTimeout;
  const PanelTitle({required this.panel, this.onTimeout});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        child: ListTile(
          title: Text(
            panel.title ?? panel.name ?? '',
            style: TextStyle(fontSize: 28),
          ),
          subtitle: panel.description != null
              ? Text(
                  panel.description!,
                  style: TextStyle(fontSize: 24),
                )
              : null,
        ),
      ),
    );
  }
}
