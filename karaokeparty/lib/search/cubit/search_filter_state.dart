part of 'search_filter_cubit.dart';

final class SearchFilterState {
  const SearchFilterState({required this.languages, required this.decade, required this.duets, required this.singles});

  final Set<String> languages;
  final String? decade;
  final bool singles;
  final bool duets;
}
