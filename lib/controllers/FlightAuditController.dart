import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';

class CabinController extends GetxController {
  final box = GetStorage();

  // প্রতিটি সিটের ডাটা স্টোর করার জন্য Map
  var auditedSeats = <String, Map<String, dynamic>>{}.obs;

  // ড্রপডাউন এবং অন্যান্য ফিল্ড
  var selectedGate = 'Please Select One'.obs;
  var selectedSupervisor = 'Please Select One'.obs;
  var selectedAircraft = 'Please Select One'.obs;

  @override
  void onInit() {
    super.onInit();
    var stored = box.read('cabin_audit_data');
    if (stored != null) {
      auditedSeats.value = Map<String, Map<String, dynamic>>.from(stored);
    }
  }

  // সিটের ইনফরমেশন সেভ করা
  void saveSeatAudit(String id, String status, String? path, String note) {
    auditedSeats[id] = {
      'status': status,
      'image': path,
      'note': note,
      'time': DateTime.now().toString(),
    };
    box.write('cabin_audit_data', auditedSeats);
    Get.back(); // ফর্ম ক্লোজ হবে
  }

  Future<String?> takePhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    return image?.path;
  }

  /// Area key (e.g. "Front Galley") -> picked image file path.
  final areaImages = <String, String?>{}.obs;

  /// Pick image from gallery for an area (Areas section upload).
  Future<void> pickImageForArea(String areaKey) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      areaImages[areaKey] = image.path;
      areaImages.refresh();
    }
  }
}