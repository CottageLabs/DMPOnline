# Set the path to the repository folder, used for queuing operations, e.g.
# REPOSITORY_PATH = "/Users/martyn/development/dmponline3/repository"

REPOSITORY_PATH = Rails.root.join('repository')

REPOSITORY_LOG_LENGTH = 100

Time::DATE_FORMATS[:repository_time] = "%d-%b-%y %H:%M:%S"