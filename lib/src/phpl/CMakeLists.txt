add_dynamic_library(
    NAME phpl
    SOURCES
        phpl.cpp

    HEADERS
        phpl.h

    COMPILE_FLAGS
        -fopenmp
    LINK_LIBRARIES
        -fopenmp
)

# Пробрасываем имена целей на верхний уровень (обязательно)
set(LIB_TARGET  ${LIB_TARGET}  PARENT_SCOPE)
set(COPY_TARGET ${COPY_TARGET} PARENT_SCOPE)