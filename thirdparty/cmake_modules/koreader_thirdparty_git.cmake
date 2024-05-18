include_guard(GLOBAL)

find_package(Git)

function(git)
    list(JOIN ARGN " " CMD)
    message(STATUS "${GIT_EXECUTABLE} ${CMD}")
    execute_process(COMMAND ${GIT_EXECUTABLE} ${ARGN} RESULT_VARIABLE git_error)
    set(git_error ${git_error} PARENT_SCOPE)
endfunction()

function(clone git_repository git_tag git_submodules src_name clone_checkout build_source_dir)

    # Default depth
    set(git_clone_depth 50)

    if(git_tag STREQUAL "")
        message(FATAL_ERROR "Tag for git checkout should not be empty.")
    endif()

    ######################################################################
    # 1. if not cloned before, do it
    # 2. try to checkout the requested revision 3 times:
    #   - if the 1st try fails: try to fetch only the requested revision
    #   - if the 2nd try fails: try to unshallow the repository
    #   - if the 3rd try fails: game over…
    # 3. update the requested sub-modules
    # 4. copy everything over to source directory
    ######################################################################

    if(NOT EXISTS ${clone_checkout})
        # try the clone 3 times in case there is an odd git clone issue
        set(git_error 1)
        set(number_of_tries 0)
        while(git_error AND number_of_tries LESS 3)
            git(clone --depth ${git_clone_depth} ${git_repository} ${clone_checkout})
            math(EXPR number_of_tries "${number_of_tries} + 1")
        endwhile()
        if(number_of_tries GREATER 1)
            message(WARNING "Had to git clone more than once: ${number_of_tries} times.")
        endif()
        if(git_error)
            message(FATAL_ERROR "Failed to clone repository: '${git_repository}'")
        endif()
        git(-C ${clone_checkout} sparse-checkout init)
        if(git_error)
            message(WARNING "Failed to enable sparse checkout in: '${clone_checkout}'")
        endif()
    endif()

    # checkout the requested revision
    foreach(TRY RANGE 1 3)
        git(-C ${clone_checkout} -c advice.detachedHead=false checkout --force ${git_tag} --)
        if(NOT git_error)
            break()
        endif()
        if(TRY EQUAL 1)
            message(STATUS "Fetching revision: '${git_tag}'")
            git(-C ${clone_checkout} fetch --recurse-submodules=no --depth ${git_clone_depth} origin "+${git_tag}:refs/remotes/origin/${git_tag}")
            if(git_error)
                message(WARNING "Failed to fetch revision from origin: '${git_tag}'")
            endif()
        elseif(TRY EQUAL 2)
            message(STATUS "Fetching full repo")
            git(-C ${clone_checkout} remote rm origin)
            git(-C ${clone_checkout} remote add origin ${git_repository})
            git(-C ${clone_checkout} fetch --unshallow --tags)
            if(git_error)
                message(WARNING "Failed to unshallow repo")
            endif()
        elseif(TRY EQUAL 3)
            message(FATAL_ERROR "Failed to checkout revision: '${git_tag}'")
        endif()
    endforeach()

    # Update sub-modules
    if(NOT git_submodules STREQUAL "none")
        git(-C ${clone_checkout} submodule update --depth ${git_clone_depth} --force --init --recursive ${git_submodules})
        if(git_error)
            message(FATAL_ERROR "Failed to update submodules in: '${clone_checkout}'")
        endif()
        git(-C ${clone_checkout} submodule foreach --recursive git sparse-checkout init)
        if(git_error)
            message(WARNING "Failed to enable submodules sparse checkouts in: '${clone_checkout}'")
        endif()
    endif()

    # Copy everything over to source directory
    if(EXISTS ${build_source_dir})
        file(REMOVE_RECURSE ${build_source_dir})
    endif()
    get_filename_component(destination_dir ${build_source_dir} DIRECTORY)
    get_filename_component(destination_name ${build_source_dir} NAME)
    get_filename_component(source_name ${clone_checkout} NAME)
    if (NOT source_name STREQUAL destination_name)
        message(FATAL_ERROR "source / destination basenames don't match: ${clone_checkout} / ${build_source_dir}")
    endif()
    file(COPY ${clone_checkout} DESTINATION ${destination_dir})

    git(-C ${build_source_dir} sparse-checkout disable)
    if(git_error)
        message(WARNING "Failed to disable sparse checkout in: '${build_source_dir}'")
    endif()

    if(NOT git_submodules STREQUAL "none")
        git(-C ${build_source_dir} submodule foreach --recursive git sparse-checkout disable)
        if(git_error)
            message(WARNING "Failed to disable submodules sparse checkouts in: '${build_source_dir}'")
        endif()
    endif()

endfunction()

set(ko_thirdparty_git ${CMAKE_CURRENT_LIST_FILE})

function(ko_write_gitclone_script script_filename git_repository git_tag build_source_dir)
    set(clone_dir ${CMAKE_CURRENT_SOURCE_DIR}/build/source)
    set(tmp_dir ${CMAKE_CURRENT_BINARY_DIR}/tmp)
    if(ARGC GREATER 4)
        set(git_submodules ${ARGV4})
        separate_arguments(git_submodules)
    endif()

    set(${script_filename} ${tmp_dir}/${PROJECT_NAME}-gitclone-${git_tag}.cmake)
    set(${script_filename} ${${script_filename}} PARENT_SCOPE)

    file(WRITE ${${script_filename}}
"
include(${ko_thirdparty_git})
file(LOCK \"${clone_dir}.lock\")
clone(
    \"${git_repository}\"
    \"${git_tag}\"
    \"${git_submodules}\"
    \"${PROJECT_NAME}\"
    \"${clone_dir}\"
    \"${build_source_dir}\"
)
file(LOCK \"${clone_dir}.lock\" RELEASE)
"
    )
endfunction()
