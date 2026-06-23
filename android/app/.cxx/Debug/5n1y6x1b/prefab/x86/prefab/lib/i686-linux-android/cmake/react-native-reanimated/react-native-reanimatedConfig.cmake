if(NOT TARGET react-native-reanimated::reanimated)
add_library(react-native-reanimated::reanimated SHARED IMPORTED)
set_target_properties(react-native-reanimated::reanimated PROPERTIES
    IMPORTED_LOCATION "/home/joshua/Desktop/Oweitu Mobile App/OweituMobile/node_modules/react-native-reanimated/android/build/intermediates/cxx/Debug/q291m5c2/obj/x86/libreanimated.so"
    INTERFACE_INCLUDE_DIRECTORIES "/home/joshua/Desktop/Oweitu Mobile App/OweituMobile/node_modules/react-native-reanimated/android/build/prefab-headers/reanimated"
    INTERFACE_LINK_LIBRARIES ""
)
endif()

