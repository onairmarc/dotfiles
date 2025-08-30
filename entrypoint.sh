source "$DF_ROOT_DIRECTORY/.autoloader/autoloader.sh"

# Run migrations before loading platform-specific configurations
if [ -f "$DF_ROOT_DIRECTORY/.framework/migrations/migrate.sh" ]; then
  source "$DF_ROOT_DIRECTORY/.framework/migrations/migrate.sh"
  run_all_migrations
fi

if [ "$OSTYPE" != "msys" ]; then
  source "$DF_AUTOLOADER_DIRECTORY/mac.sh"
else
  source "$DF_AUTOLOADER_DIRECTORY/windows.sh"
fi