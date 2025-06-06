# Combined Slack export processing script
# Generates PDFs and simple CSV like slack_export.R
# Optionally generates detailed CSV and metadata like slack_export_detailed_analysis.R

library(optparse)
library(rjson)
library(dplyr)
library(rmarkdown)
library(pagedown)

option_list <- list(
  make_option(c("-e", "--export"), type="character", help="Slack export folder"),
  make_option(c("-d", "--detailed"), action="store_true", default=FALSE,
              help="Include detailed message metadata")
)
opt <- parse_args(OptionParser(option_list=option_list))
if (is.null(opt$export)) stop("--export is required")

export_name <- opt$export
slackexport_folder_path <- file.path(getwd(), export_name)
channels_path <- file.path(slackexport_folder_path, "channels.json")
channels_json <- fromJSON(file = channels_path)

# Helper to list JSON files per channel
for (i in seq_along(channels_json)) {
  channel_folder_path <- file.path(slackexport_folder_path, channels_json[[i]]$name)
  channels_json[[i]]$dayslist <- list.files(channel_folder_path, full.names = TRUE)
}

# Convert a Slack JSON list to a data frame
slack_json_to_dataframe <- function(slack_json, detailed=FALSE) {
  if (detailed) {
    messages_df <- setNames(data.frame(matrix(ncol = 10, nrow = 0)),
      c("msg_id","ts","user","type","text","reply_count",
        "reply_users_count","ts_latest_reply","ts_thread","parent_user_id"))
  } else {
    messages_df <- setNames(data.frame(matrix(ncol = 3, nrow = 0)),
      c("ts","user","text"))
  }

  for (m in seq_along(slack_json)) {
    rec <- slack_json[[m]]
    if (detailed) {
      messages_df <- rbind(messages_df, data.frame(
        msg_id = if (!is.null(rec$client_msg_id)) rec$client_msg_id else NA,
        ts = if (!is.null(rec$ts)) rec$ts else NA,
        user = if (!is.null(rec$user)) rec$user else NA,
        type = if (!is.null(rec$type)) rec$type else NA,
        text = if (!is.null(rec$text)) rec$text else NA,
        reply_count = if (!is.null(rec$reply_count)) rec$reply_count else NA,
        reply_users_count = if (!is.null(rec$reply_users_count)) rec$reply_users_count else NA,
        ts_latest_reply = if (!is.null(rec$latest_reply)) rec$latest_reply else NA,
        ts_thread = if (!is.null(rec$thread_ts)) rec$thread_ts else NA,
        parent_user_id = if (!is.null(rec$parent_user_id)) rec$parent_user_id else NA,
        stringsAsFactors = FALSE))
    } else {
      messages_df <- rbind(messages_df, data.frame(
        ts = if (!is.null(rec$ts)) rec$ts else NA,
        user = if (!is.null(rec$user)) rec$user else NA,
        text = if (!is.null(rec$text)) rec$text else NA,
        stringsAsFactors = FALSE))
    }
  }
  messages_df
}

# Store text for PDFs and CSV
all_channels_text <- list()
all_channels_df <- setNames(data.frame(matrix(ncol = if(opt$detailed) 11 else 2, nrow = 0)),
                            if (opt$detailed)
                              c("msg_id","ts","user","type","text","reply_count",
                                "reply_users_count","ts_latest_reply","ts_thread",
                                "parent_user_id","channel")
                            else
                              c("channel_name","text"))

for (ch in seq_along(channels_json)) {
  channel_info <- channels_json[[ch]]
  all_channel_text <- c()
  channel_df <- NULL
  if (length(channel_info$dayslist) > 0) {
    for (f in channel_info$dayslist) {
      import_file_json <- fromJSON(file = f)
      import_file_df <- slack_json_to_dataframe(import_file_json, opt$detailed)
      if (opt$detailed) {
        channel_df <- rbind(channel_df, import_file_df)
      }
      all_channel_text <- c(all_channel_text, import_file_df$text)
      if (!opt$detailed) {
        for (msg in seq_len(nrow(import_file_df))) {
          all_channels_df <- rbind(all_channels_df, data.frame(
            channel_name = channel_info$name,
            text = import_file_df$text[msg], stringsAsFactors = FALSE))
        }
      }
    }
    all_channels_text[[channel_info$name]] <- paste(all_channel_text, collapse="\n")
    if (opt$detailed) {
      channel_df$channel <- channel_info$name
      all_channels_df <- rbind(all_channels_df, channel_df)
    }
  }
}

# Write PDFs and simple CSV
for (channel_name in names(all_channels_text)) {
  pdf_content <- paste0("Channel: ", channel_name, "\n\n", all_channels_text[[channel_name]], "\n")
  html_filename <- paste0(export_name, "_", channel_name, ".html")
  pdf_filename <- paste0(export_name, "_", channel_name, ".pdf")
  cat(pdf_content, file = "temp_text.Rmd")
  rmarkdown::render("temp_text.Rmd", output_format = "html_document", output_file = html_filename)
  pagedown::chrome_print(html_filename, output = pdf_filename)
  file.remove("temp_text.Rmd", html_filename)
}

if (opt$detailed) {
  filename_mindate <- min(all_channels_df$ts, na.rm = TRUE) %>% as.numeric() %>% as.POSIXct(origin="1970-01-01")
  filename_maxdate <- max(all_channels_df$ts, na.rm = TRUE) %>% as.numeric() %>% as.POSIXct(origin="1970-01-01")
  slack_export_df_filename <- paste0(export_name, "_", filename_mindate, "_to_", filename_maxdate, ".csv")
  write.csv(all_channels_df, file = slack_export_df_filename, row.names = FALSE)

  users_path <- file.path(slackexport_folder_path, "users.json")
  users_json <- fromJSON(file = users_path)
  user_list_df <- setNames(data.frame(matrix(ncol = 11, nrow = 0)),
    c("user_id","team_id","name","deleted","real_name","tz","tz_label",
      "tz_offset","title","display_name","is_bot"))
  for (u in seq_along(users_json)) {
    user <- users_json[[u]]
    user_list_df <- rbind(user_list_df, data.frame(
      user_id = user$id,
      team_id = user$team_id,
      name = user$name,
      deleted = user$deleted,
      real_name = if (!is.null(user$real_name)) user$real_name else user$profile$real_name,
      tz = if (!is.null(user$tz)) user$tz else NA,
      tz_label = if (!is.null(user$tz_label)) user$tz_label else NA,
      tz_offset = if (!is.null(user$tz_offset)) user$tz_offset else NA,
      title = user$profile$title,
      display_name = user$profile$display_name,
      is_bot = user$is_bot,
      stringsAsFactors = FALSE))
  }
  write.csv(user_list_df, file = paste0(export_name, "_users.csv"), row.names = FALSE)

  channel_list <- setNames(data.frame(matrix(ncol = 9, nrow = 0)),
    c("ch_id","name","created","creator","is_archived","is_general","members","topic","purpose"))
  for (ch in seq_along(channels_json)) {
    ch_info <- channels_json[[ch]]
    memberlist <- if (length(ch_info$members)>0) paste(ch_info$members, collapse=", ") else ""
    channel_list <- rbind(channel_list, data.frame(
      ch_id = ch_info$id,
      name = ch_info$name,
      created = ch_info$created,
      creator = ch_info$creator,
      is_archived = ch_info$is_archived,
      is_general = ch_info$is_general,
      members = memberlist,
      topic = ch_info$topic$value,
      purpose = ch_info$purpose$value,
      stringsAsFactors = FALSE))
  }
  write.csv(channel_list, file = paste0(export_name, "_channels.csv"), row.names = FALSE)
} else {
  write.csv(all_channels_df, file = paste0(export_name, "_all_channels.csv"), row.names = FALSE)
}

