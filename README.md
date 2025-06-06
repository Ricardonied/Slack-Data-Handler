# Slack Export Processing Toolkit

This repository contains two R scripts designed to help process and analyze Slack workspace exports. These tools automate the transformation of raw Slack JSON exports into structured outputs, including PDFs and CSVs, suitable for archiving, reporting, or data analysis.

---

## 📁 Scripts Overview

### 1. `slack_export_to_pdf_and_csv.R`

**Purpose**:  
Generates a PDF file for each channel with the full conversation history, and exports a consolidated CSV with all message texts from the Slack export.

**Main Features**:
- Reads all exported channel and message files.
- Extracts messages (`ts`, `user`, `text`) from each day per channel.
- Combines all messages into a single text block per channel.
- Generates:
  - One PDF per channel with formatted conversation logs.
  - A single CSV file with all messages across all channels.

**Output Files**:
- `projectname_channelname.pdf` (one per channel)
- `projectname_all_channels.csv`

---

### 2. `slack_export_detailed_analysis.R`

**Purpose**:  
Creates detailed CSV files for messages, users, and channel metadata, enabling advanced analysis (e.g., text mining, communication patterns, or thread tracking).

**Main Features**:
- Extracts message-level metadata such as:
  - `msg_id`, `ts`, `user`, `type`, `text`, `thread_ts`, replies
- Builds structured datasets:
  - All messages across all channels
  - User metadata (from `users.json`)
  - Channel metadata (from `channels.json`)

**Output Files**:
- `projectname_startdate_to_enddate.csv`: messages with full metadata
- `projectname_users.csv`: user information
- `projectname_channels.csv`: channel structure and properties

---

## 📦 Required Packages

Both scripts rely on the following R packages:

```r
install.packages("rjson")
install.packages("dplyr")
install.packages("rmarkdown")     # (for PDF generation script only)
install.packages("pagedown")      # (for PDF generation script only)
