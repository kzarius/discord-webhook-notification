# Discord Notification Script

This script allows you to send notifications to a Discord channel using a webhook. You can customize the content and embeds of the Discord message. Additionally, you can attach a file to the message if needed. Combined with other scripts and automations on your system a useful tool for alerting users or administrators about important events or changes in your environment.

## Table of Contents

- [Overview](#overview)
- [Usage](#usage)
- [Requirements](#requirements)
- [Instructions](#instructions)
- [Script Details](#script-details)
  - [Discord Variables](#discord-variables)
  - [Limit Checks](#limit-checks)
  - [Discord Notification](#discord-notification)
- [Example Usage](#example-usage)

## Overview

This Bash script is designed to send notifications to a Discord channel using Discord webhooks. It can send both plain text messages and messages with embedded content. Additionally, it supports sending attachments with notifications. The script will check if the message content is within the limits set by Discord and attempt to split the message if possible.

## Usage

To use this script, you can follow the instructions below:

```shell
Usage: ./msg.sh [OPTIONS]

Options:
  -c, --content <content>   Set the content of the Discord message.
  -e, --embeds <embeds>     Set the embeds of the Discord message.
  -f, --file <file-path>    Attach a file to the Discord message.
  -d, --debug               Enableds debug console output.
  -h, --help                Show this help message and exit.
```

## Requirements

Before using this script, make sure you have the following requirements:

- Curl (for making HTTP requests)
- Jq (for json parsing in limit checks)
- Discord Channel

## Instructions

Copy the files to a location on your machine and use it from any other script or code you might have.

You can get the **ID** (numbers) and **token** (alphanumerical) and by going into the settings for the Discord channel you want the notifications to be sent to and create a new webhook under *Integration -> Webhooks*. Create a webhook and click the *'Copy Webhook URL'*.

The **user** is just a string with any username you want to appear on the notification. The **avatar URL** and the message icon are URLs to the image files you want to use in the notification. I use [imgur](https://imgur.com) to host the image files I am using.

The **role id** is the Discord ID for a role you create on your Discord channel which you want to get pinged when any issues are detected. You can get the role ID by typing `\@rolename` in a channel on your Discord server.

## Script Details

### Discord Variables

To securely manage your Discord webhook token and other sensitive information, it's recommended to store these secret variables in a separate script. Ensure that this file is not publicly accessible or included in your version control system.

- **`DISCORD_TOKEN`**: Your Discord webhook token.
- **`DISCORD_ID`**: The Discord webhook ID.
- **`DISCORD_USERNAME`**: The username for the notification message.
- **`DISCORD_AVATAR_URL`**: The URL of the avatar for the notification.
- **`DISCORD_ROLE_ID`**: The role ID for mentions in the notification.

These variables are imported from a separate `.env` script, which you should configure with your Discord user and channel details.

### Limit Checks

Discord has some limits reagarding the data that can be sent with the webhook (See [Discord Webhook field limits](https://birdie0.github.io/discord-webhooks-guide/other/field_limits.html)). The script will attempt to check the JSON data to be sent against these limits and based on the result split the message over several webhooks if possible. Otherwise the script will fail.

### Discord Notification

The script assembles the Discord notification in JSON format, including the username, content, avatar URL, and embeds. It then sends the notification to the specified Discord channel using the webhook.

You can choose to send plain text messages or messages with embedded content. Additionally, you can attach a file to the notification if needed.

The last message sendt will be saved to a file for debug purposes.

## Example Usage

Send a simple text message to Discord:

```shell
./msg.sh -c "Hello, Discord!"
```

Send a message with an embed field:

```shell
./msg.sh -c "Check out this embed" -e '{"title":"Embed Title","description":"This is an example embed."}'
```

Send a message with an attachment:

```shell
./msg.sh -c "This webhook includes a file" -e '{"title":"Embed Title","description":"This is an example embed."}' -f "/home/user/cool.file"
```