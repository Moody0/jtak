import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/controllers/app/base_provider.dart';

class BaseView<T extends BaseProvider> extends StatefulWidget {
  final T modelProvider;
  final Widget Function(BuildContext context, T modelProvider) builder;
  final Function(T modelProvider)? onModelReady;
  const BaseView({
    Key? key,
    required this.modelProvider,
    required this.builder,
    this.onModelReady,
  }) : super(key: key);

  @override
  _BaseViewState<T> createState() => _BaseViewState<T>();
}

class _BaseViewState<T extends BaseProvider> extends State<BaseView<T>> {
  @override
  void initState() {
    if (widget.onModelReady != null) {
      widget.onModelReady!(widget.modelProvider);
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<T>(
        create: (context) => widget.modelProvider,
        child: Consumer<T>(
          builder: (context, value, child) {
            return widget.builder(context, value);
          },
        ));
  }
}
