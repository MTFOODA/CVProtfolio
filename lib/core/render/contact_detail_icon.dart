import 'package:flutter/material.dart';

/// Contact icons and brand logos, matched by the document exporters.
class ContactDetailIcon extends StatelessWidget {
  const ContactDetailIcon({
    super.key,
    required this.label,
    required this.style,
    required this.size,
    required this.color,
  });
  final String label;
  final String style;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: style == 'plain' ? EdgeInsets.zero : const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: style == 'plain' ? null : color.withValues(alpha: .08),
      border: style == 'plain'
          ? null
          : Border.all(color: color.withValues(alpha: .3), width: .5),
      borderRadius: BorderRadius.circular(
        style == 'circle'
            ? 40
            : style == 'rounded'
            ? 4
            : 0,
      ),
    ),
    child: Icon(
      switch (label) {
        'GitHub' => const IconData(0xf09b, fontFamily: 'CvBrandIcons'),
        'LinkedIn' => const IconData(0xf08c, fontFamily: 'CvBrandIcons'),
        'Email' => const IconData(0xe0e1, fontFamily: 'CvContactIcons'),
        'Phone' => const IconData(0xe0cd, fontFamily: 'CvContactIcons'),
        'Location' => const IconData(0xe55f, fontFamily: 'CvContactIcons'),
        'Website' => const IconData(0xe894, fontFamily: 'CvContactIcons'),
        _ => const IconData(0xe157, fontFamily: 'CvContactIcons'),
      },
      size: size,
      color: color,
    ),
  );
}
