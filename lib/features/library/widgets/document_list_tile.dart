import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/database/models.dart';
import '../../../core/utils/date_formatters.dart';

class DocumentListTile extends StatelessWidget {
  const DocumentListTile({
    super.key,
    required this.document,
    this.onTap,
    this.onFavorite,
  });

  final DocumentModel document;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    final thumbnail = document.thumbnailPath;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            image: thumbnail != null
                ? DecorationImage(
                    image: FileImage(File(thumbnail)),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: thumbnail == null
              ? const Icon(Icons.description)
              : null,
        ),
        title: Text(document.title),
        subtitle: Text(
          '${DateFormatters.shortDate.format(document.updatedAt)} • ${document.pageCount} pages',
        ),
        trailing: IconButton(
          icon: Icon(document.isFavorite ? Icons.star : Icons.star_border),
          onPressed: onFavorite,
        ),
      ),
    );
  }
}
