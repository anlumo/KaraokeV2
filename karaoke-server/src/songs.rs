use std::path::PathBuf;

use serde::Serialize;
use tantivy::{
    collector::TopDocs,
    query::QueryParser,
    schema::{Field, Schema, STORED, TEXT},
    Document, Index, Searcher,
};

#[derive(Debug, Clone, Serialize)]
pub struct Song {
    pub row_id: i64,
    #[serde(skip)]
    pub path: PathBuf,
    pub title: String,
    pub artist: String,
    pub language: Option<String>,
    pub year: Option<u16>,
    pub duration: f32,
    pub lyrics: Option<String>,
    #[serde(skip)]
    pub cover_path: Option<PathBuf>,
}

pub struct SearchIndex {
    rowid_field: Field,
    title_field: Field,
    artist_field: Field,
    language_field: Field,
    year_field: Field,
    lyrics_field: Field,
    duration_field: Field,

    searcher: Searcher,
    query_parser: QueryParser,
}

impl SearchIndex {
    pub fn new<'a>(input: impl IntoIterator<Item = &'a Song>) -> anyhow::Result<Self> {
        let mut schema_builder = Schema::builder();
        let rowid_field = schema_builder.add_i64_field("rowid", STORED);
        let title_field = schema_builder.add_text_field("title", TEXT | STORED);
        let artist_field = schema_builder.add_text_field("artist", TEXT | STORED);
        let language_field = schema_builder.add_text_field("language", STORED);
        let year_field = schema_builder.add_text_field("year", TEXT | STORED);
        let lyrics_field = schema_builder.add_text_field("lyrics", TEXT | STORED);
        let duration_field = schema_builder.add_f64_field("duration", STORED);
        let schema = schema_builder.build();

        let index = Index::create_in_ram(schema);

        let mut index_writer = index.writer(20_000_000)?;

        for song in input {
            let mut doc = Document::new();
            doc.add_i64(rowid_field, song.row_id);
            doc.add_text(title_field, song.title.clone());
            doc.add_text(artist_field, song.artist.clone());
            doc.add_f64(duration_field, song.duration as _);
            if let Some(song_language) = song.language.as_ref() {
                doc.add_text(language_field, song_language.clone());
            }
            if let Some(song_year) = song.year {
                doc.add_text(year_field, song_year.to_string());
            }
            if let Some(song_lyrics) = song.lyrics.as_ref() {
                doc.add_text(lyrics_field, song_lyrics);
            }
            index_writer.add_document(doc)?;
        }

        index_writer.commit()?;

        let reader = index.reader()?;
        let searcher = reader.searcher();

        let query_parser = QueryParser::for_index(
            &index,
            vec![artist_field, title_field, year_field, lyrics_field],
        );

        Ok(Self {
            rowid_field,
            title_field,
            artist_field,
            language_field,
            year_field,
            lyrics_field,
            duration_field,
            searcher,
            query_parser,
        })
    }

    pub fn search(&self, query: &str) -> tantivy::Result<Vec<serde_json::Value>> {
        let query = self.query_parser.parse_query(query)?;
        let top_songs = self.searcher.search(&query, &TopDocs::with_limit(50))?;

        top_songs
            .into_iter()
            .map(|(weight, address)| {
                let song = self.searcher.doc(address)?;
                let mut json: serde_json::Map<String, serde_json::Value> = [
                    (
                        "id".to_owned(),
                        serde_json::Value::Number(
                            song.get_first(self.rowid_field)
                                .unwrap()
                                .as_i64()
                                .unwrap()
                                .into(),
                        ),
                    ),
                    (
                        "weight".to_owned(),
                        serde_json::Value::Number(
                            serde_json::Number::from_f64(weight as _).unwrap(),
                        ),
                    ),
                    (
                        "title".to_owned(),
                        serde_json::Value::String(
                            song.get_first(self.title_field)
                                .unwrap()
                                .as_text()
                                .unwrap()
                                .to_owned(),
                        ),
                    ),
                    (
                        "artist".to_owned(),
                        serde_json::Value::String(
                            song.get_first(self.artist_field)
                                .unwrap()
                                .as_text()
                                .unwrap()
                                .to_owned(),
                        ),
                    ),
                    (
                        "duration".to_owned(),
                        serde_json::Value::Number(
                            serde_json::Number::from_f64(
                                song.get_first(self.duration_field)
                                    .unwrap()
                                    .as_f64()
                                    .unwrap(),
                            )
                            .unwrap(),
                        ),
                    ),
                ]
                .into_iter()
                .collect();
                if let Some(language) = song.get_first(self.language_field) {
                    json.insert(
                        "language".to_owned(),
                        serde_json::Value::String(language.as_text().unwrap().to_owned()),
                    );
                }
                if let Some(year) = song.get_first(self.year_field) {
                    json.insert(
                        "year".to_owned(),
                        serde_json::Value::String(year.as_text().unwrap().to_owned()),
                    );
                }
                if let Some(lyrics) = song.get_first(self.lyrics_field) {
                    json.insert(
                        "lyrics".to_owned(),
                        serde_json::Value::String(lyrics.as_text().unwrap().to_owned()),
                    );
                }

                Ok(serde_json::Value::Object(json))
            })
            .collect()
    }
}
