import 'package:flutter_bloc/flutter_bloc.dart';

part 'search_filter_state.dart';

class SearchFilterCubit extends Cubit<SearchFilterState> {
  SearchFilterCubit() : super(const SearchFilterState(language: null, decade: null));

  String? get language => state.language;
  String? get decade => state.decade;

  set language(String? language) {
    emit(SearchFilterState(language: language, decade: decade));
  }

  set decade(String? decade) {
    emit(SearchFilterState(language: language, decade: decade));
  }
}
