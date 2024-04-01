import 'package:hydrated_bloc/hydrated_bloc.dart';

part 'search_filter_state.dart';

class SearchFilterCubit extends HydratedCubit<SearchFilterState> {
  SearchFilterCubit() : super(const SearchFilterState(languages: {}, decade: null, duet: null));

  Set<String> get languages => state.languages;
  String? get decade => state.decade;
  bool? get duet => state.duet;

  set languages(Iterable<String> languages) {
    emit(SearchFilterState(languages: Set.from(languages), decade: decade, duet: duet));
  }

  void addLanguage(String language) {
    emit(SearchFilterState(
      languages: {
        ...languages,
        language,
      },
      decade: decade,
      duet: duet,
    ));
  }

  void removeLanguage(String language) {
    emit(SearchFilterState(
      languages: languages.where((element) => element != language).toSet(),
      decade: decade,
      duet: duet,
    ));
  }

  void toggleLanguage(String language) {
    if (languages.contains(language)) {
      removeLanguage(language);
    } else {
      addLanguage(language);
    }
  }

  set decade(String? decade) {
    emit(SearchFilterState(languages: languages, decade: decade, duet: duet));
  }

  set duet(bool? duet) {
    emit(SearchFilterState(languages: languages, decade: decade, duet: duet));
  }

  String? queryString(String? text) {
    if (text == null && state.languages.isEmpty && state.decade == null && state.duet == null) {
      return null;
    }

    return [
      if (text != null) text,
      if (state.languages.isNotEmpty) '(${state.languages.map((lang) => 'language:"$lang"').join(' OR ')})',
      if (state.decade != null) 'year:[${state.decade!}]',
      if (state.duet != null) 'duet:${state.duet}',
    ].join(' AND ');
  }

  @override
  SearchFilterState fromJson(Map<String, dynamic> json) => SearchFilterState(
        languages: Set.from(json['languages']),
        decade: json['decade'],
        duet: json['duet'],
      );

  @override
  Map<String, dynamic> toJson(SearchFilterState state) => {
        'languages': state.languages.toList(growable: false),
        'decade': state.decade,
        'duet': state.duet,
      };
}
