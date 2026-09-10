import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class RatingBarWidget extends StatefulWidget {
  final double rate;
  final Function(double rating)? onRatingUpdateHandler;
  final bool allowHalfRating;
  final double itemSize;
  final int itemCount;
  final double minRating;
  final EdgeInsetsGeometry itemPadding;
  final Axis direction;

  const RatingBarWidget({
    this.onRatingUpdateHandler,
    this.rate = 1,
    this.itemCount = 5,
    this.itemSize = 25,
    this.minRating = 1,
    this.allowHalfRating = false,
    this.itemPadding = const EdgeInsets.symmetric(horizontal: 5),
    this.direction = Axis.horizontal,
  });

  @override
  _RatingBarWidgetState createState() => _RatingBarWidgetState();
}

class _RatingBarWidgetState extends State<RatingBarWidget> {
  late double rate;
  @override
  void initState() {
    super.initState();
    rate = widget.rate;
  }

  @override
  void didUpdateWidget(covariant RatingBarWidget oldWidget) {
    if (widget.rate != rate) rate = widget.rate;
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onRatingUpdateHandler == null) {
      return RatingBarIndicator(
        rating: rate,
        itemBuilder: (context, index) => const Icon(Icons.star, color: Colors.amber),
        itemCount: widget.itemCount,
        itemSize: widget.itemSize,
        direction: widget.direction,
        unratedColor: Colors.grey.shade300,
      );
    }

    return RatingBar.builder(
      initialRating: rate,
      minRating: widget.minRating,
      direction: widget.direction,
      allowHalfRating: widget.allowHalfRating,
      itemCount: widget.itemCount,
      itemSize: widget.itemSize,
      itemPadding: widget.itemPadding,
      unratedColor: Colors.grey.shade300,
      glowColor: Colors.grey.shade400,
      itemBuilder: (context, index) => const Icon(Icons.star, color: Colors.amber),
      onRatingUpdate: (value) {
        setState(() => rate = value);
        widget.onRatingUpdateHandler!(value);
      },
    );
  }
}
