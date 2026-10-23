include_guard(GLOBAL)

function(add_dynamic_library)
    set(oneValueArgs NAME)
    set(multiValueArgs SOURCES HEADERS COMPILE_FLAGS LINK_LIBRARIES)
    cmake_parse_arguments(ARG "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT ARG_NAME)
        message(FATAL_ERROR "add_dynamic_library: NAME argument is required")
    endif()

    set(LIB_NAME  ${ARG_NAME})
    set(COPY_TARGET copy_headers_${LIB_NAME})

    # ---------- 1. Цель сборки ----------
    if(ARG_SOURCES)
        # Есть исходники -> создаём динамическую библиотеку
        add_library(${LIB_NAME} SHARED ${ARG_SOURCES})

        get_filename_component(LIB_PARENT_DIR ${CMAKE_CURRENT_SOURCE_DIR} DIRECTORY)
        target_include_directories(${LIB_NAME} PRIVATE
                ${CMAKE_CURRENT_SOURCE_DIR}
                ${LIB_PARENT_DIR}
        )

        if(ARG_COMPILE_FLAGS)
            target_compile_options(${LIB_NAME} PRIVATE ${ARG_COMPILE_FLAGS})
        endif()

        if(ARG_LINK_LIBRARIES)
            target_link_libraries(${LIB_NAME} PRIVATE ${ARG_LINK_LIBRARIES})
        endif()

        set_target_properties(${LIB_NAME} PROPERTIES
                LIBRARY_OUTPUT_DIRECTORY "${LIB_BUILD_DIR}"
                PREFIX "lib"
                SUFFIX ".so"
        )
    elseif(ARG_HEADERS)
        # Исходников нет, но есть заголовки -> создаём интерфейсную библиотеку,
        add_library(${LIB_NAME} INTERFACE)
    else()
        # Совсем ничего нет — пустая библиотека не создаётся
        set(LIB_NAME "")
    endif()

    # ---------- 2. Добавление заголовков в библиотечную цель ----------
    if(ARG_HEADERS AND LIB_NAME)
        # Превращаем относительные пути в абсолютные для единообразия
        set(HEADER_SRCS_ABS)
        foreach(HEADER ${ARG_HEADERS})
            if(IS_ABSOLUTE ${HEADER})
                list(APPEND HEADER_SRCS_ABS ${HEADER})
            else()
                list(APPEND HEADER_SRCS_ABS ${CMAKE_CURRENT_SOURCE_DIR}/${HEADER})
            endif()
        endforeach()

        # Добавляем заголовки к цели. Для SHARED это просто исходные файлы,
        # для INTERFACE — интерфейсные исходники. IDE увидит их в составе цели.
        if(ARG_SOURCES)
            target_sources(${LIB_NAME} PRIVATE ${HEADER_SRCS_ABS})
        else()
            target_sources(${LIB_NAME} INTERFACE ${HEADER_SRCS_ABS})
        endif()
    endif()

    # ---------- 3. Копирование заголовков (отдельная custom цель) ----------
    if(ARG_HEADERS)
        set(COPY_COMMANDS)
        foreach(HEADER ${ARG_HEADERS})
            if(IS_ABSOLUTE ${HEADER})
                set(HDR_SRC ${HEADER})
            else()
                set(HDR_SRC ${CMAKE_CURRENT_SOURCE_DIR}/${HEADER})
            endif()

            file(RELATIVE_PATH HDR_REL ${CMAKE_CURRENT_SOURCE_DIR} ${HDR_SRC})
            set(HDR_DST ${LIB_INCLUDES_DIR}/${LIB_NAME}/${HDR_REL})
            get_filename_component(HDR_DST_DIR ${HDR_DST} DIRECTORY)

            list(APPEND COPY_COMMANDS
                    COMMAND ${CMAKE_COMMAND} -E make_directory "${HDR_DST_DIR}"
                    COMMAND ${CMAKE_COMMAND} -E copy_if_different "${HDR_SRC}" "${HDR_DST}"
            )
        endforeach()

        add_custom_target(${COPY_TARGET}
                ${COPY_COMMANDS}
                DEPENDS ${HEADER_SRCS_ABS}
                COMMENT "Copying public headers for ${LIB_NAME}"
        )

        if(LIB_NAME)
            add_dependencies(${LIB_NAME} ${COPY_TARGET})
        endif()
    else()
        # Заголовков нет — создаём пустую custom цель для совместимости
        add_custom_target(${COPY_TARGET})
    endif()

    # ---------- 4. Экспорт целей в родительскую область ----------
    set(LIB_TARGET  ${LIB_NAME}      PARENT_SCOPE)
    set(COPY_TARGET ${COPY_TARGET}   PARENT_SCOPE)
endfunction()