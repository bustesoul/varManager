class VarsQueryParams {
  VarsQueryParams({
    this.page = 1,
    this.perPage = 50,
    this.search = '',
    this.creator = '',
    this.installed = 'all',
    this.sort = 'meta_date',
    this.order = 'desc',
  });

  final int page;
  final int perPage;
  final String search;
  final String creator;
  final String installed;
  final String sort;
  final String order;

  Map<String, String> toQuery() {
    final query = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
      'sort': sort,
      'order': order,
    };
    if (search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    if (creator.trim().isNotEmpty && creator.trim() != 'ALL') {
      query['creator'] = creator.trim();
    }
    if (installed != 'all') {
      query['installed'] = installed;
    }
    return query;
  }

  VarsQueryParams copyWith({
    int? page,
    int? perPage,
    String? search,
    String? creator,
    String? installed,
    String? sort,
    String? order,
  }) {
    return VarsQueryParams(
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
      search: search ?? this.search,
      creator: creator ?? this.creator,
      installed: installed ?? this.installed,
      sort: sort ?? this.sort,
      order: order ?? this.order,
    );
  }
}

class ScenesQueryParams {
  ScenesQueryParams({
    this.page = 1,
    this.perPage = 50,
    this.search = '',
    this.creator = '',
    this.category = 'scenes',
    this.installed = 'all',
    this.hideFav = 'all',
    this.sort = 'var_date',
    this.order = 'desc',
  });

  final int page;
  final int perPage;
  final String search;
  final String creator;
  final String category;
  final String installed;
  final String hideFav;
  final String sort;
  final String order;

  Map<String, String> toQuery() {
    final query = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
      'sort': sort,
      'order': order,
    };
    if (search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    if (creator.trim().isNotEmpty && creator.trim() != 'ALL') {
      query['creator'] = creator.trim();
    }
    if (category.trim().isNotEmpty) {
      query['category'] = category.trim();
    }
    if (installed != 'all') {
      query['installed'] = installed;
    }
    if (hideFav != 'all') {
      query['hide_fav'] = hideFav;
    }
    return query;
  }

  ScenesQueryParams copyWith({
    int? page,
    int? perPage,
    String? search,
    String? creator,
    String? category,
    String? installed,
    String? hideFav,
    String? sort,
    String? order,
  }) {
    return ScenesQueryParams(
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
      search: search ?? this.search,
      creator: creator ?? this.creator,
      category: category ?? this.category,
      installed: installed ?? this.installed,
      hideFav: hideFav ?? this.hideFav,
      sort: sort ?? this.sort,
      order: order ?? this.order,
    );
  }
}
