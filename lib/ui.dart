import 'package:flutter/material.dart';

import 'items.dart';

const _seed = Color(0xFF00796B); // teal, matches the launcher icon

ThemeData appTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: brightness,
    // Warm amber accent for things still waiting (Adobe links).
    tertiaryContainer: dark ? const Color(0xFF5C3B00) : const Color(0xFFFFE0B2),
    onTertiaryContainer: dark ? const Color(0xFFFFDDB3) : const Color(0xFF4E2600),
  );
  final base = ThemeData(colorScheme: scheme);
  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      titleTextStyle: base.textTheme.headlineSmall?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: scheme.primary,
        letterSpacing: -0.5,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(0, 52))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48))),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                child: Icon(Icons.print_rounded, size: 48, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(height: 16),
              Text('Junta todo e imprime una vez', style: text.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              const _Step(1, 'Elige PDFs', 'Márcalos todos en la carpeta WhatsApp Documents'),
              const _Step(2, 'Pega links de Adobe', 'Copia los mensajes en WhatsApp y toca "Pegar links"'),
              const _Step(3, 'Imprime todo', 'Los links se bajan solos y sale una sola impresión'),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.number, this.title, this.detail);

  final int number;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            child: Text('$number', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                Text(detail, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ItemCard extends StatelessWidget {
  const ItemCard({super.key, required this.item, required this.onRemove});

  final PrintItem item;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isAdobe = item.url != null;
    final (label, bg, fg) = switch (item.status) {
      ItemStatus.ready => ('Listo', scheme.primaryContainer, scheme.onPrimaryContainer),
      ItemStatus.pending => ('Por bajar', scheme.tertiaryContainer, scheme.onTertiaryContainer),
      ItemStatus.error => ('Error', scheme.errorContainer, scheme.onErrorContainer),
    };
    final detail = switch (item.status) {
      ItemStatus.error => isAdobe ? 'No se pudo bajar: reintenta o quítalo' : 'No se pudo usar: quítalo',
      ItemStatus.pending => item.url!,
      ItemStatus.ready => isAdobe ? 'Bajado de Adobe' : 'PDF',
    };

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isAdobe ? scheme.tertiaryContainer : scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isAdobe ? Icons.link_rounded : Icons.picture_as_pdf_rounded,
            color: isAdobe ? scheme.onTertiaryContainer : scheme.onSecondaryContainer,
          ),
        ),
        title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
                child: Text(label, style: text.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        trailing: IconButton(icon: const Icon(Icons.close_rounded), tooltip: 'Quitar', onPressed: onRemove),
      ),
    );
  }
}
