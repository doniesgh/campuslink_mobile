import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_badge.dart';
import '../../domain/entities/lost_item.dart';

// Icons and colors shared by the Lost & Found card and request sheet.

/// Thumbnail placeholder (no photos until the API serves them).
IconData lostItemCategoryIcon(LostItemCategory category) => switch (category) {
      LostItemCategory.calculator => Icons.calculate_outlined,
      LostItemCategory.keys => Icons.key_outlined,
      LostItemCategory.audio => Icons.headphones_outlined,
      LostItemCategory.bag => Icons.backpack_outlined,
      LostItemCategory.card => Icons.badge_outlined,
      LostItemCategory.bottle => Icons.water_drop_outlined,
      LostItemCategory.other => Icons.inventory_2_outlined,
    };

IconData lostItemPlaceIcon(LostItemPlace place) => switch (place) {
      LostItemPlace.classroom => Icons.meeting_room_outlined,
      LostItemPlace.parking => Icons.local_parking,
      LostItemPlace.library => Icons.local_library_outlined,
      LostItemPlace.cafeteria => Icons.restaurant_outlined,
      LostItemPlace.other => Icons.place_outlined,
    };

/// Readable green for text and icons (tertiary in the mockup).
Color lostFoundSuccessColor(ColorScheme scheme) => toneColors(scheme, BadgeTone.success).$2;

/// Readable coral for text and icons on light surfaces.
Color lostFoundAccentText(ColorScheme scheme) => toneColors(scheme, BadgeTone.accent).$2;

/// Leading stripe / icon color of a card, by what the student can do with it:
/// purple to claim, coral for a lost item, green for a serial-number check.
Color lostItemAccent(ColorScheme scheme, LostItemAction action) => switch (action) {
      LostItemAction.claim => scheme.primary,
      LostItemAction.reportFound => scheme.secondary,
      LostItemAction.verifySerial => toneColors(scheme, BadgeTone.success, solid: true).$1,
    };
