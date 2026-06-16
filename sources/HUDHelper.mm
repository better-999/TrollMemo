//
//  HUDHelper.mm
//  TrollMemo
//
//  Created by Lessica on 2024/1/24.
//

#import <spawn.h>
#import <notify.h>
#import <mach-o/dyld.h>
#import <unistd.h>
#import <signal.h>
#import <errno.h>

#import "HUDHelper.h"
#import "NSUserDefaults+Private.h"

extern "C" char **environ;

#define POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE 1
extern "C" int posix_spawnattr_set_persona_np(const posix_spawnattr_t* __restrict, uid_t, uint32_t);
extern "C" int posix_spawnattr_set_persona_uid_np(const posix_spawnattr_t* __restrict, uid_t);
extern "C" int posix_spawnattr_set_persona_gid_np(const posix_spawnattr_t* __restrict, uid_t);


#define LAUNCH_DAEMON_RELATIVE @"/Library/LaunchDaemons/ch.better.hudservices.plist"

static void HUDSpawnApplyRootPersona(posix_spawnattr_t *attr)
{
#if !TARGET_OS_SIMULATOR
    // TrollStore 也需要 root persona 才能显示全局 HUD（与 TrollSpeed 一致）
    posix_spawnattr_set_persona_np(attr, 99, POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE);
    posix_spawnattr_set_persona_uid_np(attr, 0);
    posix_spawnattr_set_persona_gid_np(attr, 0);
#endif
}

static const char *HUDExecutablePath(void)
{
    static char *executablePath = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *path = [[NSBundle mainBundle] executablePath];
        if (path.length > 0) {
            executablePath = strdup(path.fileSystemRepresentation);
            return;
        }
        uint32_t size = 0;
        _NSGetExecutablePath(NULL, &size);
        executablePath = (char *)calloc(1, size);
        _NSGetExecutablePath(executablePath, &size);
    });
    return executablePath;
}

static void EnsureHUDRuntimePaths(void)
{
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:[HUDResolvedPath(HUD_PID_PATH) stringByDeletingLastPathComponent]
    withIntermediateDirectories:YES
                     attributes:nil
                          error:nil];
    [fm createDirectoryAtPath:[HUDResolvedPath(USER_DEFAULTS_PATH) stringByDeletingLastPathComponent]
    withIntermediateDirectories:YES
                     attributes:nil
                          error:nil];
}

BOOL IsJailbrokenHUDEnvironment(void)
{
    static dispatch_once_t onceToken;
    static BOOL jailbroken = NO;
    dispatch_once(&onceToken, ^{
        jailbroken = (access("/var/jb", F_OK) == 0)
            || (access("/Library/PreferenceBundles/TrollMemoPrefs.bundle", F_OK) == 0)
            || (access("/var/jb/Library/PreferenceBundles/TrollMemoPrefs.bundle", F_OK) == 0);
    });
    return jailbroken;
}

NSString *HUDResolvedPath(NSString *path)
{
#if TARGET_OS_SIMULATOR
    return path;
#else
    if (!IsJailbrokenHUDEnvironment()) {
        return path;
    }
    return JBROOT_PATH_NSSTRING(path);
#endif
}

static BOOL IsHUDRunningFromPIDFile(void)
{
    NSString *pidPath = HUDResolvedPath(HUD_PID_PATH);
    NSString *pidString = [NSString stringWithContentsOfFile:pidPath
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil];
    if (!pidString.length) {
        return NO;
    }

    pid_t pid = (pid_t)[pidString intValue];
    if (pid <= 0) {
        return NO;
    }

    int rc = kill(pid, 0);
    if (rc == 0) {
        return YES;
    }
    // HUD 以 root 运行时，mobile 主 App 可能收到 EPERM，但进程仍在
    return errno == EPERM;
}

BOOL IsHUDEnabled(void)
{
#if !TARGET_OS_SIMULATOR
    if (!IsJailbrokenHUDEnvironment()) {
        return IsHUDRunningFromPIDFile();
    }
#endif

    static char *executablePath = NULL;
    uint32_t executablePathSize = 0;
    _NSGetExecutablePath(NULL, &executablePathSize);
    executablePath = (char *)calloc(1, executablePathSize);
    _NSGetExecutablePath(executablePath, &executablePathSize);

    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);
    HUDSpawnApplyRootPersona(&attr);

    int rc;
    pid_t task_pid;
    const char *args[] = { executablePath, "-check", NULL };
    rc = posix_spawn(&task_pid, executablePath, NULL, &attr, (char **)args, environ);
    if (rc != 0) {
        log_debug(OS_LOG_DEFAULT, "posix_spawn error %s", strerror(rc));
    }

    posix_spawnattr_destroy(&attr);

    if (rc != 0) {
        return IsHUDRunningFromPIDFile();
    }

    log_debug(OS_LOG_DEFAULT, "spawned %{public}s -check pid = %{public}d", executablePath, task_pid);
    
    int status = 0;
    do {
        if (waitpid(task_pid, &status, 0) != -1)
        {
            log_debug(OS_LOG_DEFAULT, "child status %d", WEXITSTATUS(status));
        }
    } while (!WIFEXITED(status) && !WIFSIGNALED(status));

    return WEXITSTATUS(status) != 0;
}

void SetHUDEnabled(BOOL isEnabled)
{
    if (isEnabled) {
        EnsureHUDRuntimePaths();
    } else {
        notify_post(NOTIFY_DISMISSAL_HUD);
    }

    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);
    HUDSpawnApplyRootPersona(&attr);

    BOOL launchDaemonHandled = NO;
    NSString *launchDaemonPath = HUDResolvedPath(LAUNCH_DAEMON_RELATIVE);
    if (IsJailbrokenHUDEnvironment() && access(launchDaemonPath.fileSystemRepresentation, F_OK) == 0)
    {
        if (!isEnabled) {
            [NSThread sleepForTimeInterval:FADE_OUT_DURATION];
        }

        int rc;
        pid_t task_pid;
        static const char *launchctlPath = JBROOT_PATH_CSTRING("/usr/bin/launchctl");
        const char *args[] = { launchctlPath, isEnabled ? "load" : "unload", launchDaemonPath.fileSystemRepresentation, NULL };
        rc = posix_spawn(&task_pid, launchctlPath, NULL, &attr, (char **)args, environ);
        if (rc == 0) {
            int status = 0;
            do {
                if (waitpid(task_pid, &status, 0) != -1) {
                    log_debug(OS_LOG_DEFAULT, "launchctl child status %d", WEXITSTATUS(status));
                }
            } while (!WIFEXITED(status) && !WIFSIGNALED(status));

            if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
                launchDaemonHandled = YES;
            }
        } else {
            log_debug(OS_LOG_DEFAULT, "posix_spawn launchctl error %s", strerror(rc));
        }
    }

    if (launchDaemonHandled) {
        posix_spawnattr_destroy(&attr);
        return;
    }

    static const char *executablePath = NULL;
    static dispatch_once_t execOnceToken;
    dispatch_once(&execOnceToken, ^{
        executablePath = HUDExecutablePath();
    });

    if (isEnabled)
    {
        posix_spawnattr_setpgroup(&attr, 0);
        posix_spawnattr_setflags(&attr, POSIX_SPAWN_SETPGROUP);

        int rc;
        pid_t task_pid;
        const char *args[] = { executablePath, "-hud", NULL };
        rc = posix_spawn(&task_pid, executablePath, NULL, &attr, (char **)args, environ);
        if (rc != 0) {
            log_debug(OS_LOG_DEFAULT, "posix_spawn -hud error %s", strerror(rc));
        }

        posix_spawnattr_destroy(&attr);

        if (rc != 0) {
            return;
        }

        log_debug(OS_LOG_DEFAULT, "spawned %{public}s -hud pid = %{public}d", executablePath, task_pid);
    }
    else
    {
        notify_post(NOTIFY_DISMISSAL_HUD);
        [NSThread sleepForTimeInterval:FADE_OUT_DURATION];

        int rc;
        pid_t task_pid;
        const char *args[] = { executablePath, "-exit", NULL };
        rc = posix_spawn(&task_pid, executablePath, NULL, &attr, (char **)args, environ);
        if (rc != 0) {
            log_debug(OS_LOG_DEFAULT, "posix_spawn -exit error %s", strerror(rc));
        }

        posix_spawnattr_destroy(&attr);

        if (rc != 0) {
            return;
        }

        log_debug(OS_LOG_DEFAULT, "spawned %{public}s -exit pid = %{public}d", executablePath, task_pid);

        int status;
        do {
            if (waitpid(task_pid, &status, 0) != -1)
            {
                log_debug(OS_LOG_DEFAULT, "child status %d", WEXITSTATUS(status));
            }
        } while (!WIFEXITED(status) && !WIFSIGNALED(status));
    }
}

#if DEBUG
void SimulateMemoryPressure(void)
{
    static NSString *nsExecutablePath = nil;
    static const char *executablePath = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle *mainBundle = [NSBundle mainBundle];
        nsExecutablePath = [mainBundle pathForResource:@"memory_pressure" ofType:nil];
        if (nsExecutablePath) {
            executablePath = [nsExecutablePath UTF8String];
        }
    });

    if (!executablePath) {
        return;
    }

    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);

#if !TARGET_OS_SIMULATOR
    posix_spawnattr_set_persona_np(&attr, 99, POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE);
    posix_spawnattr_set_persona_uid_np(&attr, 0);
    posix_spawnattr_set_persona_gid_np(&attr, 0);
#endif

    pid_t task_pid;
    const char *args[] = { executablePath, "-l", "critical", NULL };
    posix_spawn(&task_pid, executablePath, NULL, &attr, (char **)args, environ);
    posix_spawnattr_destroy(&attr);

    log_debug(OS_LOG_DEFAULT, "spawned %{public}s -l critical pid = %{public}d", executablePath, task_pid);
}
#endif

NSUserDefaults *GetStandardUserDefaults(void)
{
    static NSUserDefaults *_userDefaults = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *containerPath = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject] stringByDeletingLastPathComponent];
        NSURL *containerURL = [NSURL fileURLWithPath:containerPath];
        _userDefaults = [[NSUserDefaults alloc] _initWithSuiteName:nil container:containerURL];
        [_userDefaults registerDefaults:@{
            HUDUserDefaultsKeyUsesCustomOffset: @NO,
            HUDUserDefaultsKeyRealCustomOffsetX: @0,
            HUDUserDefaultsKeyRealCustomOffsetY: @0,
            HUDUserDefaultsKeyUsesCustomFontSize: @NO,
            HUDUserDefaultsKeyRealCustomFontSize: @9,
        }];
    });
    return _userDefaults;
}

NSMutableDictionary *LoadHUDSettingsPlist(void)
{
    return [[NSDictionary dictionaryWithContentsOfFile:HUDResolvedPath(USER_DEFAULTS_PATH)] mutableCopy] ?: [NSMutableDictionary dictionary];
}

BOOL SaveHUDSettingsPlist(NSDictionary *settings)
{
    NSString *resolvedPath = HUDResolvedPath(USER_DEFAULTS_PATH);
    BOOL wroteSucceed = [settings writeToFile:resolvedPath atomically:YES];
    if (wroteSucceed) {
        [[NSFileManager defaultManager] setAttributes:@{
            NSFileOwnerAccountID: @501,
            NSFileGroupOwnerAccountID: @501,
        } ofItemAtPath:resolvedPath error:nil];
    }
    return wroteSucceed;
}
