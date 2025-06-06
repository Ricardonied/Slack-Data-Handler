# 📚 Slack Conversation Analysis Toolkit

This repository contains three main R scripts designed to assist in the extraction, structuring, and analysis of Slack workspace exports. Together, these tools enable both human-readable reporting and advanced text mining of Slack conversations.

---

## 📁 Overview of Scripts

### 1. `slack_export.R`

**Purpose**:  
Generates formatted **PDF files** for each Slack channel and a consolidated **CSV file** with all messages for archival or reading.

**Main Features**:
- Parses Slack export JSON files.
- Extracts message text from each channel and day.
- Produces:
  - One PDF per channel with formatted content.
  - One CSV with raw messages across all channels.

**Output**:
- `projectname_channelname.pdf`
- `projectname_all_channels.csv`

---

### 2. `slack_export_combined.R`

**Purpose**:
Single entry point that replicates `slack_export.R` and, when run with the `--detailed` flag, also produces rich metadata tables.

**Main Features**:
- Generates channel PDFs and a basic CSV of messages.
- Optional `--detailed` mode adds message threads, user and channel metadata.

**Output**:
- Basic mode: `projectname_all_channels.csv` plus one PDF per channel.
- Detailed mode: `projectname_<startdate>_to_<enddate>.csv` with message metadata, `projectname_users.csv`, and `projectname_channels.csv`.

---

### 3. `slack_topic_modelling.R`

**Purpose**:  
Performs **natural language processing (NLP)** and **topic modeling** on the text extracted from Slack PDFs, enabling insight into the main topics and vocabulary trends.

**Main Features**:
- Reads all PDFs (generated in the first script).
- Cleans and tokenizes text.
- Removes stopwords (standard and custom).
- Performs **lemmatization** (word normalization).
- Generates:
  - Most frequent words
  - Word clouds
  - Topic modeling using Structural Topic Models (STM)
  - Document-topic probabilities

**Visual Output**:
- Word frequency bar charts
- Word clouds
- Topic-term distribution plots
- Document-topic assignment visualization

**Use Cases**:
- Thematic exploration of Slack conversations.
- Supporting qualitative research and communication analysis.
- Identifying trends, concerns, or dominant topics in teams.

---

## 🔧 Required R Packages

Ensure the following packages are installed:

```r
install.packages(c(
  "optparse", "rjson", "dplyr", "rmarkdown", "pagedown", "tidytext", "tm",
  "tidymodels", "stm", "reshape2", "forcats", "knitr", "ggplot2",
  "textstem", "wordcloud", "pdftools", "broom", "RColorBrewer"
))

```

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
