const fs = require('fs');
const path = 'D:/Huawei/WritingApp/entry/build/default/intermediates/cmake/default/obj/arm64-v8a/libgguf.so';
try {
  fs.unlinkSync(path);
  fs.writeFileSync('D:/Huawei/WritingApp/delete_result.txt', 'Deleted successfully');
} catch(e) {
  fs.writeFileSync('D:/Huawei/WritingApp/delete_result.txt', 'Error: ' + e.message);
}
