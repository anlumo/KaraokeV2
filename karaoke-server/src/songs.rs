use rand::Rng;
use serde::Serialize;
use tantivy::{
    collector::{Collector, TopDocs},
    query::{AllQuery, Query, QueryParser},
    schema::{Field, Schema, FAST, INDEXED, STORED, STRING, TEXT},
    DocAddress, DocId, Document, Index, IndexReader, IndexSettings, IndexSortByField,
    SegmentReader,
};

use crate::Pagination;

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Song {
    pub row_id: i64,
    pub title: String,
    pub artist: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub language: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub year: Option<i64>,
    pub duration: f64,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub lyrics: Option<String>,
    pub duet: bool,
    #[serde(default)]
    pub cover_path: Option<String>,
    pub audio_path: String,
}

pub struct SearchIndex {
    rowid_field: Field,
    title_field: Field,
    artist_field: Field,
    language_field: Field,
    year_field: Field,
    lyrics_field: Field,
    duration_field: Field,
    duet_field: Field,
    cover_field: Field,
    audio_field: Field,

    reader: IndexReader,
    query_parser: QueryParser,
}

impl SearchIndex {
    pub fn new<'a>(input: impl IntoIterator<Item = &'a Song>) -> anyhow::Result<Self> {
        let mut schema_builder = Schema::builder();
        let order_field = schema_builder.add_u64_field("order", STORED | FAST);
        let rowid_field = schema_builder.add_i64_field("rowid", INDEXED | STORED);
        let title_field = schema_builder.add_text_field("title", TEXT | STORED);
        let artist_field = schema_builder.add_text_field("artist", TEXT | STORED);
        let language_field = schema_builder.add_text_field("language", TEXT | STORED);
        let year_field = schema_builder.add_text_field("year", STRING | STORED);
        let lyrics_field = schema_builder.add_text_field("lyrics", TEXT | STORED);
        let duration_field = schema_builder.add_f64_field("duration", STORED);
        let duet_field = schema_builder.add_bool_field("duet", INDEXED | STORED);
        let cover_field = schema_builder.add_text_field("cover", STORED);
        let audio_field = schema_builder.add_text_field("audio", STORED);
        let schema = schema_builder.build();

        let mut index = Index::builder()
            .schema(schema)
            .settings(IndexSettings {
                sort_by_field: Some(IndexSortByField {
                    field: "order".to_owned(),
                    order: tantivy::Order::Asc,
                }),
                ..Default::default()
            })
            .create_in_ram()?;
        index.set_default_multithread_executor()?;

        let mut index_writer = index.writer(50_000_000)?;

        for (order, song) in input.into_iter().enumerate() {
            let mut doc = Document::new();
            doc.add_i64(rowid_field, song.row_id);
            doc.add_u64(order_field, order as _);
            doc.add_text(title_field, song.title.clone());
            doc.add_text(artist_field, song.artist.clone());
            doc.add_f64(duration_field, song.duration as _);
            if let Some(song_language) = &song.language {
                doc.add_text(language_field, song_language.to_owned());
            }
            if let Some(song_year) = song.year {
                doc.add_text(year_field, song_year.to_string());
            }
            if let Some(song_lyrics) = &song.lyrics {
                doc.add_text(lyrics_field, song_lyrics);
            }
            doc.add_bool(duet_field, song.duet);
            if let Some(cover) = &song.cover_path {
                doc.add_text(cover_field, cover);
            }
            doc.add_text(audio_field, &song.audio_path);
            index_writer.add_document(doc)?;
        }

        index_writer.commit()?;

        let reader = index.reader()?;

        let mut query_parser = QueryParser::for_index(
            &index,
            vec![
                artist_field,
                title_field,
                language_field,
                year_field,
                lyrics_field,
            ],
        );
        query_parser.set_field_fuzzy(lyrics_field, false, 2, true);
        query_parser.set_field_boost(title_field, 3.0);
        query_parser.set_field_boost(artist_field, 2.0);
        query_parser.set_conjunction_by_default();

        Ok(Self {
            rowid_field,
            title_field,
            artist_field,
            language_field,
            year_field,
            lyrics_field,
            duration_field,
            duet_field,
            cover_field,
            audio_field,
            reader,
            query_parser,
        })
    }

    fn search_internal<OrderValue, C: Collector<Fruit = Vec<(OrderValue, DocAddress)>>>(
        &self,
        query: &dyn Query,
        collector: C,
    ) -> tantivy::Result<Vec<Song>> {
        let searcher = self.reader.searcher();
        let results = searcher.search(query, &collector)?;

        results
            .into_iter()
            .map(|(_, address)| {
                let song = searcher.doc(address)?;

                let song = Song {
                    row_id: song.get_first(self.rowid_field).unwrap().as_i64().unwrap(),
                    title: song
                        .get_first(self.title_field)
                        .unwrap()
                        .as_text()
                        .unwrap()
                        .to_owned(),
                    artist: song
                        .get_first(self.artist_field)
                        .unwrap()
                        .as_text()
                        .unwrap()
                        .to_owned(),
                    language: song
                        .get_first(self.language_field)
                        .map(|language| language.as_text().unwrap().to_owned()),
                    year: song
                        .get_first(self.year_field)
                        .map(|year| year.as_text().unwrap().parse().unwrap()),
                    duration: song
                        .get_first(self.duration_field)
                        .unwrap()
                        .as_f64()
                        .unwrap(),
                    lyrics: song
                        .get_first(self.lyrics_field)
                        .map(|lyrics| lyrics.as_text().unwrap().to_owned()),
                    duet: song
                        .get_first(self.duet_field)
                        .map(|duet| duet.as_bool().unwrap_or_default())
                        .unwrap_or_default(),
                    cover_path: song
                        .get_first(self.cover_field)
                        .map(|cover| cover.as_text().unwrap().to_owned()),
                    audio_path: song
                        .get_first(self.audio_field)
                        .map(|cover| cover.as_text().unwrap().to_owned())
                        .unwrap_or_default(),
                };
                Ok(song)
            })
            .collect()
    }

    fn search_and_convert<OrderValue, C: Collector<Fruit = Vec<(OrderValue, DocAddress)>>>(
        &self,
        query: &dyn Query,
        collector: C,
    ) -> tantivy::Result<Vec<serde_json::Value>> {
        let songs = self.search_internal(query, collector)?;

        Ok(songs
            .into_iter()
            .map(|song| serde_json::to_value(song).unwrap())
            .collect())
    }

    pub fn search(&self, query: &str) -> tantivy::Result<Vec<serde_json::Value>> {
        self.search_and_convert(
            &self.query_parser.parse_query(query)?,
            TopDocs::with_limit(50),
        )
    }

    pub fn search_song(&self, query: &str, limit: usize) -> tantivy::Result<Vec<Song>> {
        self.search_internal(
            &self.query_parser.parse_query(query)?,
            TopDocs::with_limit(limit),
        )
    }

    pub fn paginated(&self, pagination: Pagination) -> tantivy::Result<Vec<serde_json::Value>> {
        let collector = TopDocs::with_limit(pagination.per_page.min(100) as _)
            .and_offset(pagination.offset as _)
            .order_by_fast_field("order", tantivy::Order::Asc);
        if let Some(query) = &pagination.query {
            self.search_and_convert::<u64, _>(&self.query_parser.parse_query(query)?, collector)
        } else {
            self.search_and_convert::<u64, _>(&AllQuery, collector)
        }
    }

    pub fn random_picks(
        &self,
        count: usize,
        query: Option<&str>,
    ) -> tantivy::Result<Vec<serde_json::Value>> {
        let collector = TopDocs::with_limit(count)
            .custom_score(|_: &SegmentReader| |_: DocId| rand::thread_rng().gen::<u32>());

        if let Some(query) = query {
            self.search_and_convert(&self.query_parser.parse_query(query)?, collector)
        } else {
            self.search_and_convert(&AllQuery, collector)
        }
    }
}

pub fn urlencode_path(path_bytes: impl IntoIterator<Item = u8>) -> String {
    let mut encoded = String::new();

    for b in path_bytes {
        if b.is_ascii_alphanumeric() || b"-._~/".contains(&b) {
            encoded.push(b as char);
        } else {
            encoded.push_str(&format!("%{:02X}", b));
        }
    }

    encoded
}
