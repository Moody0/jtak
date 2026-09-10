import 'package:flutter/material.dart';
import '../../config/constants/countries.dart';
import '../../config/themes/app_theme.dart';
import '../../config/themes/colors.dart';
import '../../core/models/country.dart';
import '../../utils/utilities/global_var.dart';
import '../../../main_imports.dart';

class CountryWidget extends StatefulWidget {
  final int? initValue;
  final Function(CountryModel country)? onChange;
  const CountryWidget({this.initValue, this.onChange});

  @override
  State<CountryWidget> createState() => _CountryWidgetState();
}

class _CountryWidgetState extends State<CountryWidget> {
  List<CountryModel> countryRefrenceList = [];
  CountryModel? country;

  @override
  void initState() {
    countryRefrenceList = List.generate(kCountries.length, (index) => CountryModel.fromMap(kCountries[index]));
    if (widget.initValue != null) {
      country = countryRefrenceList.firstWhere((element) => element.id == widget.initValue);
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        CountryModel? res = await showDialog(context: context, builder: (context) => const CountriesPicker());
        if (res != null) {
          setState(() {
            country = res;
          });
          if (widget.onChange != null) {
            widget.onChange!(res);
          }
        }
      },
      child: Container(
        width: double.infinity,
        height: 50,
        padding: AppTheme.contentPadding,
        decoration: AppTheme.getContainerBorderDecoration(),
        alignment: AlignmentDirectional.centerStart,
        child: Text(country?.title ?? str.main.pleaseChooseCountry, style: context.textTheme.bodyMedium),
      ),
    );
  }
}

class CountriesPicker extends StatefulWidget {
  const CountriesPicker();
  @override
  _CurrencyPickerState createState() => _CurrencyPickerState();
}

class _CurrencyPickerState extends State<CountriesPicker> {
  String searchQuery = '';
  List<CountryModel> countryRefrenceList = [];

  final ValueNotifier<List<CountryModel>> curList = ValueNotifier([]);

  @override
  void initState() {
    countryRefrenceList = List.generate(kCountries.length, (index) => CountryModel.fromMap(kCountries[index]));
    curList.value = countryRefrenceList.toList();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Card(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      str.main.pleaseChooseCountry,
                      style: Theme.of(context).textTheme.displaySmall!.copyWith(color: kPrimaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))
                ],
              ),
              context.addHeight(12),
              TextFormField(
                initialValue: searchQuery,
                key: const ValueKey('country_search_field'),
                decoration: AppTheme.getTextFieldDecoration(hint: str.main.search).copyWith(suffixIcon: const Icon(Icons.search)),
                onChanged: (val) {
                  searchQuery = val.trim();
                  search();
                },
              ),
              Expanded(
                child: ValueListenableBuilder<List<CountryModel>>(
                  valueListenable: curList,
                  builder: (context, value, child) => ListView.separated(
                    itemCount: value.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text('${value[index].title} '),
                        onTap: () {
                          Navigator.pop(context, value[index]);
                        },
                      );
                    },
                    separatorBuilder: (context, index) => Container(width: double.infinity, height: 1, color: Colors.grey.shade300),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void search() {
    List<CountryModel> list = [];
    if (GlobalVar.checkString(searchQuery)) {
      for (var element in countryRefrenceList) {
        if (element.title.toLowerCase().contains(searchQuery.toLowerCase())) list.add(element);
      }
      curList.value = list.toList();
    } else {
      curList.value = countryRefrenceList.toList();
    }
  }
}
