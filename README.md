
# Backup Automation Script

This project is a **Backup Automation Script** designed to back up databases (MariaDB, MongoDB) and directories specified in a JSON configuration file. It supports automatic log creation, old backup cleanup, and error reporting.

## Features

- **Backup MariaDB databases**: Dumps database contents using `mysqldump`.
- **Backup MongoDB databases**: Dumps database collections using `mongodump`.
- **Backup directories**: Copies entire directory contents to a temporary location.
- **Log creation**: Generates log files for each backup session.
- **Automatic cleanup**: Deletes backups older than a specified number of days.
- **Error reporting**: Tracks backup success or failure in a status file.

## Prerequisites

The following packages are required for the script to run:

- **bash**: For executing the script.
- **jq**: For parsing JSON configuration files.
- **mysqldump**: For backing up MariaDB databases.
- **mongodump**: For backing up MongoDB databases.
- **tar**: For creating archive files.

You can install them using the following commands:

```bash
sudo apt-get install jq mariadb-client mongodb-clients tar
```

## Configuration File

The script reads its configuration from a JSON file passed as an argument. Below is an example configuration file:

```json
{
    "name": "pass",
    "backup2folder": "/dockers/backupper-linux/backups",
    "log2folder": "/dockers/backupper-linux/backups",
    "backupDays": 7,
    "status": true,
    "mariadb": [
        {
            "name": "mariadb-pass",
            "enabled": true,
            "host": "mariadb",
            "port": 3306,
            "dbname": "pass",
            "dbuser": "pass",
            "dbpass": "SuperPasswordHere"
        }
    ],
    "mongodb": [
        {
            "name": "mongodb-pass",
            "enabled": false,
            "host": "localhost",
            "port": 27017,
            "dbname": "vcard",
            "dbuser": "user",
            "dbpass": "SuperPasswordHere"
        }
    ],
    "folders": [
        {
            "name": "jwt",
            "enabled": true,
            "path": "/dockers/pass/jwt"
        },
        {
            "name": "gpg",
            "enabled": true,
            "path": "/dockers/pass/gpg"
        }
    ]
}
```

## Usage

Run the script by providing the path to the configuration file:

```bash
./backup.sh --config ./configs/pass.json
```

### Example Output
```
2024-12-01 18:55:42 Deleting backups older than 7 days
2024-12-01 18:55:42 Starting backup process
2024-12-01 18:55:43 Backing up MariaDB: mariadb-pass
2024-12-01 18:55:44 Backing up folder: jwt
2024-12-01 18:55:45 Backing up folder: gpg
2024-12-01 18:55:46 Creating archive /dockers/backupper-linux/backups/pass_2024-12-01_1855.tar.gz
2024-12-01 18:55:47 Backup process completed successfully
```

## Logging

The script generates log files for each backup session. Log files are named using the format `<name>_<timestamp>.log` and are stored in the directory specified by `log2folder` in the configuration file.

## Status File

A status file is created in the backup folder to indicate the success or failure of the backup process. If all components are backed up successfully, the status file contains `OK`. If any error occurs, the status file contains `Bad`.

## CRONTAB

```
30 23 * * * cd /dockers/backupper-linux && ./backup.sh --config ./configs/sample.json
```

## License

This project is open-source and available under the MIT License.
