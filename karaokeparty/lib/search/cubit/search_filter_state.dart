part of 'search_filter_cubit.dart';

final class SearchFilterState {
  const SearchFilterState({required this.languages, required this.decade, required this.duet});

  final Set<String> languages;
  final String? decade;
  final bool? duet;
}
