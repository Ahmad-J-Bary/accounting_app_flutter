// Platform-neutral entry point for the table-preferences store. The IO
// implementation writes a small JSON document next to the application support
// data; the stub keeps everything in memory for web and tests.
export 'table_preferences_store_stub.dart'
    if (dart.library.io) 'table_preferences_store_io.dart';
