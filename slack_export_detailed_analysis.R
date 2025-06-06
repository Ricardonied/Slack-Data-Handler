# Install required packages on first run
# install.packages(c("rjson", "dplyr"))
library(rjson)  # import and manipulate JSON files
library(dplyr)  # data handling helpers

# Provide the name of the unzipped Slack export folder located in your working
# directory (for example `~/Documents`).
# export_name <- "exportunzipped"
export_name <- "Slack export Jul 1 2023 - Sep 30 2023"
working_directory <- getwd()
slackexport_folder_path <- file.path(working_directory, export_name)

# Build a list of all channels from `<export_name>/channels.json`.
channels_path <- file.path(slackexport_folder_path, "channels.json")
channels_json <- fromJSON(file = channels_path)
channel_list <- setNames(data.frame(matrix(ncol = 9, nrow = 0)), 
                         c("ch_id", "name", "created", "creator", "is_archived",
                           "is_general", "members", "topic", "purpose"))

for (channel in seq_along(channels_json)) {
  # Build a data frame with information about each channel from the JSON file
  channel_list[channel, "ch_id"] <- channels_json[[channel]]$id
  channel_list[channel, "name"] <- channels_json[[channel]]$name
  channel_list[channel, "created"] <- channels_json[[channel]]$created
  channel_list[channel, "creator"] <- channels_json[[channel]]$creator
  channel_list[channel, "is_archived"] <- channels_json[[channel]]$is_archived
  channel_list[channel, "is_general"] <- channels_json[[channel]]$is_general
  
  # Build a comma separated list of members
  memberlist <- ""
  if (length(channels_json[[channel]]$members) > 0) {
    for (member in seq_along(channels_json[[channel]]$members)) {
      if (member < length(channels_json[[channel]]$members)) {
        memberlist <- paste0(memberlist, channels_json[[channel]]$members[[member]], ", ")
      } else {
        memberlist <- paste0(memberlist, channels_json[[channel]]$members[[member]])
      }
    }
  }
  channel_list[channel, "members"] <- memberlist
  channel_list[channel, "topic"] <- channels_json[[channel]]$topic$value
  channel_list[channel, "purpose"] <- channels_json[[channel]]$purpose$value
  
  # For each channel gather the list of daily JSON files
  channel_folder_path <- file.path(slackexport_folder_path, channel_list[channel, "name"])
  channels_json[[channel]]$dayslist <- list.files(channel_folder_path, full.names = FALSE)
}

# Convert a JSON file into a data frame with selected fields
slack_json_to_dataframe <- function(slack_json) {
  # Initialize the data frame with the expected columns
  messages_df <- setNames(data.frame(matrix(ncol = 10, nrow = 0)),
                          c("msg_id", "ts", "user", "type", "text", "reply_count",
                            "reply_users_count", "ts_latest_reply", "ts_thread",
                            "parent_user_id"))
  
  # Iterate over each message in the JSON file
  for (message in seq_along(slack_json)) {
    # Replace NULL with NA to avoid errors
    msg_id <- if (!is.null(slack_json[[message]]$client_msg_id)) slack_json[[message]]$client_msg_id else NA
    ts <- if (!is.null(slack_json[[message]]$ts)) slack_json[[message]]$ts else NA
    user <- if (!is.null(slack_json[[message]]$user)) slack_json[[message]]$user else NA
    type <- if (!is.null(slack_json[[message]]$type)) slack_json[[message]]$type else NA
    text <- if (!is.null(slack_json[[message]]$text)) slack_json[[message]]$text else NA
    reply_count <- if (!is.null(slack_json[[message]]$reply_count)) slack_json[[message]]$reply_count else NA
    reply_users_count <- if (!is.null(slack_json[[message]]$reply_users_count)) slack_json[[message]]$reply_users_count else NA
    ts_latest_reply <- if (!is.null(slack_json[[message]]$latest_reply)) slack_json[[message]]$latest_reply else NA
    ts_thread <- if (!is.null(slack_json[[message]]$thread_ts)) slack_json[[message]]$thread_ts else NA
    parent_user_id <- if (!is.null(slack_json[[message]]$parent_user_id)) slack_json[[message]]$parent_user_id else NA
    
    # Add the message to the data frame
    messages_df <- rbind(messages_df, data.frame(
      msg_id = msg_id,
      ts = ts,
      user = user, 
      type = type, 
      text = text, 
      reply_count = reply_count, 
      reply_users_count = reply_users_count, 
      ts_latest_reply = ts_latest_reply, 
      ts_thread = ts_thread, 
      parent_user_id = parent_user_id,
      stringsAsFactors = FALSE
    ))
  }
  
  return(messages_df)
}

# Data frame to store all messages across channels
all_channels_all_files_df <- setNames(data.frame(matrix(ncol = 11, nrow = 0)),
                                      c("msg_id", "ts", "user", "type", "text",
                                        "reply_count", "reply_users_count",
                                        "ts_latest_reply", "ts_thread", "parent_user_id",
                                        "channel"))

# Loop over each channel
for (channel in seq_along(channels_json)) {
  # Data frame for all messages in a single channel
  all_channel_files_df <- setNames(data.frame(matrix(ncol = 10, nrow = 0)),
                                   c("msg_id", "ts", "user", "type", "text",
                                     "reply_count", "reply_users_count",
                                     "ts_latest_reply", "ts_thread", "parent_user_id"))
  
  if (length(channels_json[[channel]]$dayslist) > 0) {
    for (file_day in channels_json[[channel]]$dayslist) {
      parentfolder_path <- file.path(slackexport_folder_path, channels_json[[channel]]$name)
      filejson_path <- file.path(parentfolder_path, file_day)
      import_file_json <- fromJSON(file = filejson_path)
      
      # Convert the JSON file using `slack_json_to_dataframe`
      import_file_df <- slack_json_to_dataframe(import_file_json)
      
      # Append the day's data to the channel data frame
      all_channel_files_df <- rbind(all_channel_files_df, import_file_df)
    }
    
    # Add channel name to the data frame
    all_channel_files_df$channel <- channels_json[[channel]]$name
    
    # Append the channel data to the final data frame
    all_channels_all_files_df <- rbind(all_channels_all_files_df, all_channel_files_df)
  } else {
    warning(paste("Channel", channels_json[[channel]]$name, "has no JSON files."))
  }
}



# Write all messages to a CSV in the working directory
# Format: exportfoldername_mindate_to_maxdate.csv
filename_mindate <- min(all_channels_all_files_df$ts) %>% as.numeric() %>% as.Date.POSIXct()
filename_maxdate <- max(all_channels_all_files_df$ts) %>% as.numeric() %>% as.Date.POSIXct()
# `export_name` was defined earlier
slack_export_df_filename <- paste0(export_name, "_", filename_mindate, "_to_", filename_maxdate, ".csv")
write.csv(all_channels_all_files_df, file = slack_export_df_filename)

# TODO - how does it handle orphaned threads or deleted messages?
# TODO - make a users table with user metadata, write to csv
users_path <- file.path(slackexport_folder_path, "users.json")
users_json <- fromJSON(file = users_path)
# Initialize empty user data frame
user_list_df <- setNames(data.frame(matrix(ncol = 11, nrow = 0)),
                         c("user_id", "team_id", "name", "deleted", "real_name",
                           "tz", "tz_label", "tz_offset", "title", "display_name",
                           "is_bot"))
#fill it with the appropriate fields from JSON
for (user in 1:length(users_json)) {
  user_list_df[user, "user_id"] <- users_json[[user]]$id
  user_list_df[user, "team_id"] <- users_json[[user]]$team_id
  user_list_df[user, "name"] <- users_json[[user]]$name
  user_list_df[user, "deleted"] <- users_json[[user]]$deleted
  #real_name is in a different place for bots - its nested in $profile
  if (is.null(users_json[[user]]$real_name) == FALSE) {
    user_list_df[user, "real_name"] <- users_json[[user]]$real_name
  }
  if (is.null(users_json[[user]]$profile$real_name) == FALSE) {
    user_list_df[user, "real_name"] <- users_json[[user]]$profile$real_name
  }
  user_list_df[user, "title"] <- users_json[[user]]$profile$title
  user_list_df[user, "display_name"] <- users_json[[user]]$profile$display_name
  user_list_df[user, "is_bot"] <- users_json[[user]]$is_bot
  #bots (?not sure who else) don't have time zone information. catch that null
  if (is.null(users_json[[user]]$tz) == FALSE) {
    user_list_df[user, "tz"] <- users_json[[user]]$tz
    user_list_df[user, "tz_label"] <- users_json[[user]]$tz_label
    user_list_df[user, "tz_offset"] <- users_json[[user]]$tz_offset
  }
  
}
#write user data to a csv to be read back in as df, as needed.
slack_export_user_filename <- paste0(export_name, "_users.csv")
write.csv(user_list_df, file = slack_export_user_filename)


#Write a csv for channel metadata
#write user data to a csv to be read back in as df, as needed.
slack_export_channel_filename <- paste0(export_name, "_channels.csv")
write.csv(channel_list, file = slack_export_channel_filename)

