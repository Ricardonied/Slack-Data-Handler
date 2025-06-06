# Install required packages the first time you run the script
# install.packages(c("rjson", "dplyr", "rmarkdown", "pagedown"))
library(rjson)      # read and manipulate JSON files
library(dplyr)      # data manipulation helpers
library(rmarkdown)  # render PDFs via RMarkdown
library(pagedown)   # convert HTML to PDF using headless Chrome


# Provide the name of the unzipped Slack export folder located in your working
# directory (for example `~/Documents`).
# export_name <- "exportunzipped"
export_name <- "projeto_alpha_slack_chats"
working_directory <- getwd()
slackexport_folder_path <- file.path(working_directory, export_name)

# Build a list of channels. Information lives in `<export_name>/channels.json`.
channels_path <- file.path(slackexport_folder_path, "channels.json")
channels_json <- fromJSON(file = channels_path)
channel_list <- setNames(data.frame(matrix(ncol = 2, nrow = 0)), 
                         c("ch_id", "name"))

for (channel in seq_along(channels_json)) {
  # Build a data frame with channel id and name
  channel_list[channel, "ch_id"] <- channels_json[[channel]]$id
  channel_list[channel, "name"] <- channels_json[[channel]]$name
  # For each channel gather the list of daily JSON files
  channel_folder_path <- file.path(slackexport_folder_path, channel_list[channel, "name"])
  channels_json[[channel]]$dayslist <- list.files(channel_folder_path, full.names = FALSE)
}

# Convert a Slack JSON file into a data frame with selected fields
slack_json_to_dataframe <- function(slack_json) {
  # Initialize the data frame with the expected columns
  messages_df <- setNames(data.frame(matrix(ncol = 3, nrow = 0)),
                          c("ts", "user", "text"))
  
  # Iterate over each message in the JSON object
  for (message in seq_along(slack_json)) {
    # Replace NULLs with NA to avoid errors
    ts <- if (!is.null(slack_json[[message]]$ts)) slack_json[[message]]$ts else NA
    user <- if (!is.null(slack_json[[message]]$user)) slack_json[[message]]$user else NA
    text <- if (!is.null(slack_json[[message]]$text)) slack_json[[message]]$text else NA
    
    # Add the message to the data frame
    messages_df <- rbind(messages_df, data.frame(
      ts = ts,
      user = user,
      text = text,
      stringsAsFactors = FALSE
    ))
  }

  return(messages_df)
}

# Collect text from all channels
all_channels_text <- list()

for (channel in seq_along(channels_json)) {
  # Vector with all messages from a single channel
  all_channel_text <- c()

  if (length(channels_json[[channel]]$dayslist) > 0) {
    for (file_day in channels_json[[channel]]$dayslist) {
      parentfolder_path <- file.path(slackexport_folder_path, channels_json[[channel]]$name)
      filejson_path <- file.path(parentfolder_path, file_day)
      import_file_json <- fromJSON(file = filejson_path)

      import_file_df <- slack_json_to_dataframe(import_file_json)

      # Append text to `all_channel_text`
      all_channel_text <- c(all_channel_text, import_file_df$text)
    }

    # Save the collected text for the channel
    all_channels_text[[channels_json[[channel]]$name]] <- paste(all_channel_text, collapse = "\n")
  } else {
    warning(paste("Channel", channels_json[[channel]]$name, "has no JSON files."))
  }
}

# Render each channel into a PDF
for (channel_name in names(all_channels_text)) {
  pdf_content <- paste0("Channel: ", channel_name, "\n\n", all_channels_text[[channel_name]], "\n\n\n")

  html_filename <- paste0(export_name, "_", channel_name, ".html")
  pdf_filename <- paste0(export_name, "_", channel_name, ".pdf")

  # Write the content to a temporary RMarkdown file
  cat(pdf_content, file = "temp_text.Rmd")

  # Render the RMarkdown file to HTML
  rmarkdown::render("temp_text.Rmd", output_format = "html_document", output_file = html_filename)

  # Convert the HTML to PDF using pagedown
  pagedown::chrome_print(html_filename, output = pdf_filename)

  # Clean up temporary files
  file.remove("temp_text.Rmd")
  file.remove(html_filename)
}


# Build a data frame with the channel name and all messages
all_channels_df <- setNames(data.frame(matrix(ncol = 2, nrow = 0)),
                            c("channel_name", "text"))

for (channel in seq_along(channels_json)) {
  if (length(channels_json[[channel]]$dayslist) > 0) {
    for (file_day in channels_json[[channel]]$dayslist) {
      parentfolder_path <- file.path(slackexport_folder_path, channels_json[[channel]]$name)
      filejson_path <- file.path(parentfolder_path, file_day)
      import_file_json <- fromJSON(file = filejson_path)

      import_file_df <- slack_json_to_dataframe(import_file_json)

      for (message in seq_len(nrow(import_file_df))) {
        all_channels_df <- rbind(all_channels_df, data.frame(
          channel_name = channels_json[[channel]]$name,
          text = import_file_df$text[message],
          stringsAsFactors = FALSE
        ))
      }
    }
  } else {
    warning(paste("Channel", channels_json[[channel]]$name, "has no JSON files."))
  }
}

csv_filename <- paste0(export_name, "_all_channels.csv")
write.csv(all_channels_df, file = csv_filename, row.names = FALSE)
message("CSV file exported successfully: ", csv_filename)
