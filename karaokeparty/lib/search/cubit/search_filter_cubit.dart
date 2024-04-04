import 'package:hydrated_bloc/hydrated_bloc.dart';

part 'search_filter_state.dart';

class SearchFilterCubit extends HydratedCubit<SearchFilterState> {
  SearchFilterCubit() : super(const SearchFilterState(languages: {}, decade: null, duets: true, singles: true));

  Set<String> get languages => state.languages;
  String? get decade => state.decade;
  bool get duets => state.duets;
  bool get singles => state.singles;

  set languages(Iterable<String> languages) {
    emit(SearchFilterState(languages: Set.from(languages), decade: decade, duets: duets, singles: singles));
  }

  void addLanguage(String language) {
    emit(SearchFilterState(
      languages: {
        ...languages,
        language,
      },
      decade: decade,
      duets: duets,
      singles: singles,
    ));
  }

  void removeLanguage(String language) {
    emit(SearchFilterState(
      languages: languages.where((element) => element != language).toSet(),
      decade: decade,
      duets: duets,
      singles: singles,
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
    emit(SearchFilterState(languages: languages, decade: decade, duets: duets, singles: singles));
  }

  set duets(bool duets) {
    emit(SearchFilterState(languages: languages, decade: decade, duets: duets, singles: singles));
  }

  set singles(bool singles) {
    emit(SearchFilterState(languages: languages, decade: decade, duets: duets, singles: singles));
  }

  String? queryString(String? text) {
    if (text == null &&
        state.languages.isEmpty &&
        state.decade == null &&
        state.duets == true &&
        state.singles == true) {
      return null;
    }

    return [
      if (text != null) text,
      if (state.languages.isNotEmpty) '(${state.languages.map((lang) => 'language:"$lang"').join(' OR ')})',
      if (state.decade != null) 'year:[${state.decade!}]',
      if (state.duets && !state.singles) 'duet:true',
      if (!state.duets && state.singles) 'duet:false',
    ].join(' AND ');
  }

  @override
  SearchFilterState fromJson(Map<String, dynamic> json) => SearchFilterState(
        languages: Set.from(json['languages']),
        decade: json['decade'],
        duets: json['duets'] ?? true,
        singles: json['singles'] ?? true,
      );

  @override
  Map<String, dynamic> toJson(SearchFilterState state) => {
        'languages': state.languages.toList(growable: false),
        'decade': state.decade,
        'duets': state.duets,
        'singles': state.singles,
      };
}
