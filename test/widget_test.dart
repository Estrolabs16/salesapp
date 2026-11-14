import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:estroshop/core/widgets/brand_mark.dart';

void main() {
  testWidgets('brand mark renders inside the app chrome', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BrandHeroMark(size: 64),
                SizedBox(height: 12),
                BrandLockup(markSize: 32, titleSize: 18),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(BrandHeroMark), findsOneWidget);
    expect(find.byType(BrandLockup), findsOneWidget);
    expect(find.text('EstroShop'), findsOneWidget);
  });
}
