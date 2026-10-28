// Driver for `flutter drive` integration tests: saves the reported data to build/live_perf.json.
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data != null) await writeResponseData(data, testOutputFilename: 'live_perf', destinationDirectory: 'build');
  },
);
