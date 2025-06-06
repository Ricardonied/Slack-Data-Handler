# Script to convert a raw Slack export into PDF files and a CSV.
# It loads the JSON data for each channel, extracts all messages
# and produces one PDF per channel as well as a single CSV with
# all text messages grouped by channel.

# Install the packages required for exporting conversation history
# from Slack. Uncomment if running for the first time.
install.packages("rjson")
install.packages("dplyr")
install.packages("rmarkdown")
install.packages("pagedown")
library(rjson) #import and manipulate JSON files
library(dplyr) #data handling / pipe char
library(rmarkdown)
library(pagedown)


# Unzip the Slack export and place the extracted folder somewhere on
# your system, for example under `C:/Users/User/Documents`.
# You can set the working directory with `getwd()` if needed.
# Provide the export folder name via command line argument or, in
# interactive mode, the script will prompt for it.
args <- commandArgs(trailingOnly = TRUE)
if (interactive()) {
  export_name <- if (length(args) >= 1) args[1] else readline("Enter Slack export folder name: ")
} else {
  export_name <- if (length(args) >= 1) args[1] else "my_export_folder"
}
working_directory <- getwd() %>% as.character()
slackexport_folder_path <- paste0(working_directory, "/", export_name)

# Build a list of all channels present in the Slack export. All of
# this information is stored in `<export_name>/channels.json`.
channels_path <- paste0(slackexport_folder_path,"/channels.json")
channels_json <- fromJSON(file = channels_path)
channel_list <- setNames(data.frame(matrix(ncol = 2, nrow = 0)), 
                         c("ch_id", "name"))

for (channel in 1:length(channels_json)) {
  # Populate `channel_list` with basic information about each channel
  channel_list[channel, "ch_id"] <- channels_json[[channel]]$id
  channel_list[channel, "name"] <- channels_json[[channel]]$name
  # For each channel gather the list of JSON files (one per active day)
  # and store it in `channels_json[[channel]]$dayslist`
  channel_folder_path <- ""
  channels_json[[channel]]$dayslist <- ""
  channel_folder_path <- paste0(slackexport_folder_path,"/",channel_list[channel,"name"])
  channels_json[[channel]]$dayslist <- list.files(channel_folder_path, 
                                                  pattern=NULL, all.files=FALSE, full.names=FALSE)
}

# Helper to convert a single JSON file into a data frame with the
# fields we care about (timestamp, user id and message text).
slack_json_to_dataframe <- function(slack_json) {
  # Start a data frame with the expected columns
  messages_df <- setNames(data.frame(matrix(ncol = 3, nrow = 0)), 
                          c("ts", "user", "text"))
  
  # Iterate over each message in the JSON file
  for (message in 1:length(slack_json)) {
    # Pull the values, replacing NULL with NA to avoid errors
    ts <- if (!is.null(slack_json[[message]]$ts)) slack_json[[message]]$ts else NA
    user <- if (!is.null(slack_json[[message]]$user)) slack_json[[message]]$user else NA
    text <- if (!is.null(slack_json[[message]]$text)) slack_json[[message]]$text else NA
    
    # Append the message to the data frame
    messages_df <- rbind(messages_df, data.frame(
      ts = ts, 
      user = user, 
      text = text, 
      stringsAsFactors = FALSE
    ))
  }
  
  return(messages_df)
}

# Create a list to hold the concatenated text for each channel
all_channels_text <- list()

for (channel in 1:length(channels_json)) {
  # Vector that will hold the text of every message in a single channel
  all_channel_text <- c()
  
  if (length(channels_json[[channel]]$dayslist) > 0) {
    for (file_day in 1:length(channels_json[[channel]]$dayslist)) {
      parentfolder_path <- paste0(slackexport_folder_path,"/",channels_json[[channel]]$name)
      filejson_path <- paste0(parentfolder_path, "/", channels_json[[channel]]$dayslist[[file_day]])
      import_file_json <- fromJSON(file = filejson_path)
      
      import_file_df <- slack_json_to_dataframe(import_file_json)
      
      # Append the text to `all_channel_text`
      all_channel_text <- c(all_channel_text, import_file_df$text)
    }
    
    # After collecting all days, store the channel text into
    # the `all_channels_text` list
    all_channels_text[[channels_json[[channel]]$name]] <- paste(all_channel_text, collapse = "\n")
  } else {
    warning(paste("Channel", channels_json[[channel]]$name, "has no JSON files."))
  }
}

# Generate one PDF file per channel
for (channel_name in names(all_channels_text)) {
  # Compose the channel content
  pdf_content <- paste0("Canal: ", channel_name, "\n\n", all_channels_text[[channel_name]], "\n\n\n")
  
  # Temporary HTML name and final PDF name
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


# Inicializa um dataframe para armazenar o nome do canal e as mensagens de todos os canais
# Data frame that will collect the text of every message from all channels
all_channels_df <- setNames(data.frame(matrix(ncol = 2, nrow = 0)),
                            c("channel_name", "text"))

# Iterate again over the channels to store every message in `all_channels_df`
for (channel in 1:length(channels_json)) {
  if (length(channels_json[[channel]]$dayslist) > 0) {
    for (file_day in 1:length(channels_json[[channel]]$dayslist)) {
      parentfolder_path <- paste0(slackexport_folder_path,"/",channels_json[[channel]]$name)
      filejson_path <- paste0(parentfolder_path, "/", channels_json[[channel]]$dayslist[[file_day]])
      import_file_json <- fromJSON(file = filejson_path)
      
      import_file_df <- slack_json_to_dataframe(import_file_json)
      
      # Add channel name and messages to `all_channels_df`
      for (message in 1:nrow(import_file_df)) {
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

# Export the consolidated CSV file
csv_filename <- paste0(export_name, "_all_channels.csv")
write.csv(all_channels_df, file = csv_filename, row.names = FALSE)

message("CSV file successfully exported: ", csv_filename)
