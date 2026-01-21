import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/database/models.dart';
import '../../../core/utils/date_formatters.dart';

class DocumentCard extends StatelessWidget {
  const DocumentCard({
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
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    image: thumbnail != null
                        ? DecorationImage(
                            image: FileImage(File(thumbnail)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: thumbnail == null
                      ? const Center(child: Icon(Icons.description, size: 48))
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                document.title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                DateFormatters.shortDate.format(document.updatedAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('${document.pageCount} pages',
                      style: Theme.of(context).textTheme.bodySmall),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      document.isFavorite ? Icons.star : Icons.star_border,
                    ),
                    onPressed: onFavorite,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
