// Shimmer skeletons (same language as DeliveryFlow's Management
// shimmer): same-shape placeholders as the real content, a moving
// shine sweeping on its own, theme-aware greys. Loading feels
// faster; it never claims to BE faster. Never a bare spinner.

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

class Skeleton extends StatelessWidget {
  const Skeleton({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: dark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: dark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: child,
    );
  }
}

/// Skeleton mirroring the dashboard layout: KPI cards, chart card,
/// driver rows with avatar circle + text lines.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Expanded(child: _ShimmerBox(width: 0, height: 84)),
              SizedBox(width: 12),
              Expanded(child: _ShimmerBox(width: 0, height: 84)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(child: _ShimmerBox(width: 0, height: 84)),
              SizedBox(width: 12),
              Expanded(child: _ShimmerBox(width: 0, height: 84)),
            ],
          ),
          const SizedBox(height: 12),
          const _ShimmerBox(width: double.infinity, height: 180),
          const SizedBox(height: 12),
          for (var i = 0; i < 3; i++) ...[
            Row(
              children: const [
                _ShimmerBox(width: 44, height: 44),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ShimmerBox(width: 140, height: 14),
                      SizedBox(height: 6),
                      _ShimmerBox(width: 90, height: 12),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// Generic list skeleton: avatar + two lines per row.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.rows = 5});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: Column(
        children: [
          for (var i = 0; i < rows; i++) ...[
            Row(
              children: const [
                _ShimmerBox(width: 44, height: 44),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ShimmerBox(width: 160, height: 14),
                      SizedBox(height: 6),
                      _ShimmerBox(width: 100, height: 12),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
