import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/api/cubit/connection_cubit.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/search/cubit/search_filter_cubit.dart';

class FilterBar extends StatelessWidget {
  const FilterBar({super.key, this.child, required this.api});
  final ServerApi api;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SearchFilterCubit, SearchFilterState>(
      builder: (context, searchFilter) {
        return Row(
          children: [
            Expanded(
              child: child != null ? child! : const SizedBox(),
            ),
            const SizedBox(
              width: 8,
            ),
            Tooltip(
              message: context.t.search.searchFilterLanguagesTooltip,
              child: MenuAnchor(
                menuChildren: api.connectionCubit.state is WebSocketConnectedState
                    ? [
                        CheckboxMenuButton(
                            value: searchFilter.languages.isEmpty,
                            onChanged: (_) {
                              context.read<SearchFilterCubit>().languages = {};
                            },
                            child: Text(context.t.search.searchFilterAllLanguages)),
                        const Divider(),
                        ...(api.connectionCubit.state as WebSocketConnectedState)
                            .languages
                            .map((language) => CheckboxMenuButton(
                                value: searchFilter.languages.contains(language),
                                onChanged: (_) {
                                  context.read<SearchFilterCubit>().toggleLanguage(language);
                                },
                                child: Text(language)))
                      ]
                    : const [],
                builder: (context, controller, child) => IconButton(
                  onPressed: () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      controller.open();
                    }
                  },
                  isSelected: searchFilter.languages.isNotEmpty,
                  icon: searchFilter.languages.isEmpty
                      ? const Icon(Icons.language)
                      : Badge(
                          label: Text(searchFilter.languages.length.toString()),
                          child: const Icon(Icons.language),
                        ),
                ),
              ),
            ),
            Tooltip(
              message: context.t.search.searchFilterDecadesTooltip,
              child: MenuAnchor(
                menuChildren: [
                  RadioMenuButton(
                      value: null,
                      groupValue: searchFilter.decade,
                      onChanged: (_) {
                        context.read<SearchFilterCubit>().decade = null;
                      },
                      child: Text(context.t.search.searchFilterAllYears)),
                  const Divider(),
                  ...context.t.search.searchFilterDecades.entries.map(
                    (entry) => RadioMenuButton(
                      value: entry.key,
                      groupValue: searchFilter.decade,
                      onChanged: (_) {
                        context.read<SearchFilterCubit>().decade = entry.key;
                      },
                      child: Text(entry.value),
                    ),
                  ),
                ],
                builder: (context, controller, child) => IconButton(
                    onPressed: () {
                      if (controller.isOpen) {
                        controller.close();
                      } else {
                        controller.open();
                      }
                    },
                    isSelected: searchFilter.decade != null,
                    icon: const Icon(Icons.calendar_month)),
              ),
            ),
            Tooltip(
              message: context.t.search.searchFilterDuetTooltip,
              child: MenuAnchor(
                menuChildren: [
                  RadioMenuButton(
                      value: null,
                      groupValue: searchFilter.duet,
                      onChanged: (_) {
                        context.read<SearchFilterCubit>().duet = null;
                      },
                      child: Text(context.t.search.duets.dontCare)),
                  const Divider(),
                  RadioMenuButton(
                      value: true,
                      groupValue: searchFilter.duet,
                      onChanged: (_) {
                        context.read<SearchFilterCubit>().duet = true;
                      },
                      child: Text(context.t.search.duets.onlyDuets)),
                  RadioMenuButton(
                      value: false,
                      groupValue: searchFilter.duet,
                      onChanged: (_) {
                        context.read<SearchFilterCubit>().duet = false;
                      },
                      child: Text(context.t.search.duets.noDuets)),
                ],
                builder: (context, controller, child) => IconButton(
                    onPressed: () {
                      if (controller.isOpen) {
                        controller.close();
                      } else {
                        controller.open();
                      }
                    },
                    isSelected: searchFilter.duet != null,
                    icon: const Icon(Icons.group)),
              ),
            ),
          ],
        );
      },
    );
  }
}
