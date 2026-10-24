import 'package:flutter/material.dart';

import '../settings/settings_model.dart';
import 'design_tokens.dart';

VisualDensity visualDensityFor(AppDensity density) => switch (density) {
      AppDensity.compact => const VisualDensity(
          horizontal: DensityTokens.compactHorizontal,
          vertical: DensityTokens.compactVertical,
        ),
      AppDensity.comfortable => const VisualDensity(
          horizontal: DensityTokens.comfortableHorizontal,
          vertical: DensityTokens.comfortableVertical,
        ),
      AppDensity.spacious => const VisualDensity(
          horizontal: DensityTokens.spaciousHorizontal,
          vertical: DensityTokens.spaciousVertical,
        ),
    };