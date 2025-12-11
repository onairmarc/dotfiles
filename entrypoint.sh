source "$DF_ROOT_DIRECTORY/.autoloader/autoloader.sh"

if [ "$OSTYPE" != "msys" ]; then
  __df_source_once "$DF_AUTOLOADER_DIRECTORY/mac.sh" "autoloader_mac"
else
  __df_source_once "$DF_AUTOLOADER_DIRECTORY/windows.sh" "autoloader_windows"
fi

if [ -f "$DF_ROOT_DIRECTORY/.framework/migrations/migrate.sh" ]; then
  __df_run_migrations_optimized
fi