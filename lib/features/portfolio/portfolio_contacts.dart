import '../../core/design/app_icons.dart';
import '../../core/branding/app_branding.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/domain/profile_models.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/utils/contact_links.dart';
import '../../core/utils/input_validation.dart';

class PortfolioContactAction {
  const PortfolioContactAction(this.label, this.uri, this.copyValue, this.icon);
  final String label;
  final Uri uri;
  final String copyValue;
  final IconData icon;
}

List<PortfolioContactAction> portfolioContacts(ProfileDetails details) {
  final actions = <PortfolioContactAction>[];
  final seen = <String>{};
  for (final value in [details.website, ...details.links]) {
    final url = contactWebUrl(value);
    final kind = contactLinkKind(url);
    if (url == null || !seen.add(url)) continue;
    final portfolio = kind == 'Link' && url == contactWebUrl(details.website);
    final custom = details.linkLabels[value]?.trim();
    actions.add(
      PortfolioContactAction(
        kind != 'Link'
            ? kind
            : portfolio
            ? 'Portfolio'
            : (custom?.isNotEmpty == true ? custom! : Uri.parse(url).host),
        Uri.parse(url),
        url,
        switch (kind) {
          'GitHub' => const IconData(0xf09b, fontFamily: 'CvBrandIcons'),
          'LinkedIn' => const IconData(0xf08c, fontFamily: 'CvBrandIcons'),
          _ => portfolio ? AppIcons.portfolio : AppIcons.web,
        },
      ),
    );
  }
  final phone = internationalPhone(details.phone);
  if (phone != null) {
    actions.add(
      PortfolioContactAction(
        'WhatsApp',
        Uri.https('wa.me', '/${phone.substring(1)}'),
        phone,
        const IconData(0xf232, fontFamily: 'CvBrandIcons'),
      ),
    );
  }
  final email = details.email?.trim();
  if (email?.isNotEmpty == true && InputValidation.email(email) == null) {
    actions.add(
      PortfolioContactAction(
        'Email',
        Uri(scheme: 'mailto', path: email),
        email!,
        AppIcons.email,
      ),
    );
  }
  return actions;
}

bool contactShownAsIcon(String value, List<PortfolioContactAction> actions) {
  final url = contactWebUrl(value);
  return actions.any(
    (action) =>
        action.copyValue == value.trim() ||
        (url != null && action.uri.toString() == url) ||
        (action.label == 'WhatsApp' &&
            internationalPhone(value) == action.copyValue),
  );
}

Future<void> copyPortfolioValue(BuildContext context, String value) async {
  try {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.ui('Link copied'))));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.ui('Could not copy this link.'))),
      );
    }
  }
}

class PortfolioContactActions extends StatelessWidget {
  const PortfolioContactActions({
    super.key,
    required this.actions,
    required this.onOpen,
  });
  final List<PortfolioContactAction> actions;
  final ValueChanged<Uri> onOpen;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 4,
    children: [
      for (final action in actions)
        Tooltip(
          message: context.ui(action.label),
          triggerMode: TooltipTriggerMode.manual,
          child: GestureDetector(
            onLongPress: () => copyPortfolioValue(context, action.copyValue),
            child: IconButton(
              onPressed: () => onOpen(action.uri),
              icon: action.icon == AppIcons.portfolio
                  ? Image.asset(
                      kPortfolioLinkLogoAsset,
                      width: 26,
                      height: 26,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      colorBlendMode: BlendMode.srcIn,
                      excludeFromSemantics: true,
                    )
                  : Icon(action.icon),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
    ],
  );
}
