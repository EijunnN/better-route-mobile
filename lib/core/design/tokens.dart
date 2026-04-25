/// Barrel export for the Driver Cockpit design system. Always import this
/// file (not the individual token files) so future migrations to a different
/// token shape can be done in one place.
///
/// Usage:
/// ```dart
/// import 'package:aea/core/design/tokens.dart';
///
/// Container(
///   color: AppColors.bgSurface,
///   padding: const EdgeInsets.all(AppSpacing.space4),
///   child: Text('Hello', style: AppTypography.h3),
/// );
/// ```
library;

export 'colors.dart';
export 'motion.dart';
export 'radius.dart';
export 'shadows.dart';
export 'spacing.dart';
export 'typography.dart';
