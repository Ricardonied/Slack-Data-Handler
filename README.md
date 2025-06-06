# 📚 Slack Conversation Analysis Toolkit

This repository contains three R scripts designed to assist in the extraction, structuring, and analysis of Slack workspace exports. Together, these tools enable both human-readable reporting and advanced text mining of Slack conversations.

---

## 📁 Overview of Scripts

### 1. `slack_export`

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

### 2. `slack_export_detailed_analysis`

**Purpose**:  
Processes the Slack export with a **richer metadata structure**, suitable for research and analysis of communication patterns.

**Main Features**:
- Extracts detailed fields from message data (threads, reply counts, types).
- Includes metadata for:
  - Messages
  - Users (`users.json`)
  - Channels (`channels.json`)
- Exports structured data for further processing or machine learning.

**Output**:
- `projectname_<startdate>_to_<enddate>.csv`: full message log
- `projectname_users.csv`: user metadata
- `projectname_channels.csv`: channel structure and properties

---

### 3. `slack_topic_modelling`

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
  "rjson", "dplyr", "rmarkdown", "pagedown", "tidytext", "tm",
  "tidymodels", "stm", "reshape2", "forcats", "knitr", "ggplot2",
  "textstem", "wordcloud"
))
