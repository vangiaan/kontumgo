import 'package:flutter_test/flutter_test.dart';
import 'package:kontumgo/du_lieu.dart';

void main() {
  test('bỏ dấu tiếng Việt để tìm kiếm', () {
    expect(boDau('Măng Đen'), 'mang den');
    expect(boDau('Thác Pa Sỹ'), 'thac pa sy');
  });
}
