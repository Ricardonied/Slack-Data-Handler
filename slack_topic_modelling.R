# Script for performing topic modelling on PDFs exported by slack_export
# Cleans text, removes stopwords and builds a Structural Topic Model.

library(optparse)
library(dplyr)
library(tidytext)
library(tm)
library(tidymodels)
library(stm)
library(reshape2)
library(forcats)
library(knitr)
library(ggplot2)
library(pdftools)
library(textstem)

option_list <- list(
  make_option(c("-p", "--pdf-dir"), type="character", help="Directory containing PDFs"),
  make_option(c("-s", "--stopwords"), type="character", default=NULL,
              help="Path to custom stopwords file")
)
opt <- parse_args(OptionParser(option_list=option_list))
if (is.null(opt$pdf_dir)) stop("--pdf-dir is required")

pdf_dir <- opt$pdf_dir
pdf_files <- list.files(pdf_dir, pattern="\.pdf$", full.names=TRUE)

# Extract text from each PDF
pdf_texts <- lapply(pdf_files, pdf_text)

# Build base data frame
num_channels <- length(pdf_files)
ids <- paste0("doc", seq_len(num_channels))
channel_names <- tools::file_path_sans_ext(basename(pdf_files))
channel_data <- data.frame(id = ids, name = channel_names, text = character(num_channels), stringsAsFactors = FALSE)
for (i in seq_along(pdf_texts)) {
  channel_data$text[i] <- paste(pdf_texts[[i]], collapse=" ")
}

# Load custom stopwords if provided
custom_stopwords <- tibble(word = character())
if (!is.null(opt$stopwords)) {
  custom_stopwords <- tibble(word = readLines(opt$stopwords)) %>%
    mutate(word = tolower(word)) %>%
    mutate(word = gsub("[[:punct:]]", "", word)) %>%
    mutate(word = gsub("[[:digit:]]", "", word)) %>%
    mutate(word = gsub("[^[:alnum:]\\s]", "", word))
}

# Tokenisation and cleaning
clean_df <- channel_data %>%
  unnest_tokens(word, text) %>%
  anti_join(get_stopwords()) %>%
  anti_join(custom_stopwords) %>%
  mutate(word = gsub("[[:punct:]]", "", word)) %>%
  mutate(word = tolower(word)) %>%
  mutate(word = gsub("[[:digit:]]", "", word)) %>%
  mutate(word = gsub("[^[:alnum:]\\s]", "", word)) %>%
  filter(nchar(word) >= 3) %>%
  anti_join(get_stopwords(), by="word") %>%
  anti_join(custom_stopwords, by="word")

clean_df <- clean_df %>% mutate(word = textstem::lemmatize_words(word, language="en"))

# Basic counts
word_counts <- clean_df %>% count(word, sort=TRUE)

# Word frequency plot
freq_plot <- word_counts %>%
  top_n(25) %>%
  ggplot(aes(x=reorder(word, n), y=n)) +
  geom_bar(stat="identity", fill="blue") +
  labs(x="Word", y="Count") +
  theme(axis.text.x = element_text(angle=45, hjust=1), axis.text=element_text(size=12))
print(freq_plot)

# Topic modelling
sparse_mat <- clean_df %>% count(name, word) %>% cast_sparse(name, word, n)
model <- stm(sparse_mat, K=5)
summary(model)

# Top words per topic table
topic_words <- tidy(model, matrix="beta") %>%
  group_by(topic) %>%
  slice_max(beta, n=10) %>%
  ungroup() %>%
  mutate(term = forcats::fct_reorder(term, beta), topic = paste("Topic", topic))
print(topic_words, n=50)
knitr::kable(topic_words)

# Topic probabilities plot
topic_words %>%
  ggplot(aes(beta, term, fill=topic)) +
  geom_col(show.legend=FALSE) +
  facet_wrap(vars(topic), scales="free_y") +
  labs(x=expression(beta), y=NULL)

doc_topic <- tidy(model, matrix="gamma", document_names=rownames(sparse_mat))
print(doc_topic, n=nrow(doc_topic))

doc_topic %>%
  mutate(document = forcats::fct_reorder(document, gamma), topic=factor(topic)) %>%
  ggplot(aes(gamma, topic, fill=topic)) +
  geom_col(show.legend=FALSE) +
  facet_wrap(vars(document)) +
  theme(strip.text = element_text(size=7)) +
  labs(x=expression(gamma), y="Topic")
