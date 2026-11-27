cmake_minimum_required(VERSION 3.16)

project(icontasks2byedi-badges)

find_package(ECM 6.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

include(ECMQmlModule)

find_package(Qt6 6.6 REQUIRED COMPONENTS Core Qml DBus)

ecm_add_qml_module(badgesplugin URI local.icontasks2byedi.badges GENERATE_PLUGIN_SOURCE)
target_sources(badgesplugin PRIVATE launcherbadges.cpp launcherbadges.h badgestate.cpp badgestate.h)
target_link_libraries(badgesplugin PRIVATE Qt6::Core Qt6::Qml Qt6::DBus)
ecm_finalize_qml_module(badgesplugin DESTINATION ${KDE_INSTALL_QMLDIR})

if(BUILD_TESTING)
    find_package(Qt6 6.6 REQUIRED COMPONENTS Test)
    include(ECMAddTests)
    ecm_add_test(tests/badgestatetest.cpp badgestate.cpp
        TEST_NAME badgestatetest
        LINK_LIBRARIES Qt6::Core Qt6::Test)
    target_include_directories(badgestatetest PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
endif()
