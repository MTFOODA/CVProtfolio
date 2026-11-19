import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/session.dart';
import '../export/image_bytes.dart';
import '../utils/contact_links.dart';

class PortfolioImage extends ConsumerStatefulWidget {
  const PortfolioImage({
    super.key,
    required this.source,
    required this.ownerId,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.decodeWidth = 1280,
  });
  final String? source;
  final String ownerId;
  final Widget fallback;
  final BoxFit fit;
  final int decodeWidth;
  @override
  ConsumerState<PortfolioImage> createState() => _PortfolioImageState();
}

class _PortfolioImageState extends ConsumerState<PortfolioImage> {
  late Future<Widget?> _image;
  @override
  void initState() {
    super.initState();
    _image = _load();
  }

  @override
  void didUpdateWidget(PortfolioImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.ownerId != widget.ownerId) {
      _image = _load();
    }
  }

  Future<Widget?> _load() async {
    final source = widget.source?.trim() ?? '';
    if (source.isEmpty) return null;
    try {
      var url = source;
      var path = source;
      final uri = Uri.tryParse(source);
      final origin = Uri.tryParse(ref.read(appConfigProvider).supabaseUrl);
      if (uri != null &&
          ['http', 'https'].contains(uri.scheme) &&
          origin?.hasAuthority == true &&
          uri.origin == origin!.origin &&
          ref.read(sessionProvider2).value?.id == widget.ownerId) {
        final match = RegExp(
          r'^/storage/v1/object/(?:public|sign|authenticated)/document-media/(.+)$',
        ).firstMatch(uri.path);
        if (match != null) {
          final decoded = Uri.decodeComponent(match[1]!);
          if (decoded.startsWith('${widget.ownerId}/') &&
              !decoded.split('/').contains('..')) {
            path = decoded;
          }
        }
      }
      if (Uri.tryParse(path)?.hasScheme != true) {
        url =
            await ref.read(backendProvider).signedUrl(widget.ownerId, path) ??
            '';
      }
      if (url.startsWith('file:')) {
        // The local repository's historical Windows URLs use file://C:\...
        if (RegExp(r'^file://[A-Za-z]:').hasMatch(url)) {
          url = Uri.file(url.substring(7), windows: true).toString();
        }
        final bytes = await fetchImageBytes(url);
        if (bytes == null) return null;
        return Image.memory(
          bytes,
          fit: widget.fit,
          cacheWidth: widget.decodeWidth,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, _, _) => widget.fallback,
        );
      }
      if (contactWebUrl(url) == null) return null;
      return Image.network(
        url,
        fit: widget.fit,
        cacheWidth: widget.decodeWidth,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => widget.fallback,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : Stack(
                fit: StackFit.expand,
                children: [
                  widget.fallback,
                  Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: progress.expectedTotalBytes == null
                            ? null
                            : progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!,
                      ),
                    ),
                  ),
                ],
              ),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Widget?>(
    future: _image,
    builder: (_, snapshot) => snapshot.data ?? widget.fallback,
  );
}
