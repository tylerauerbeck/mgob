package backup

import (
	"fmt"
	"github.com/codeskyblue/go-sh"
	"github.com/pkg/errors"
	"github.com/stefanprodan/mgob/config"
	"io/ioutil"
	"strings"
	"time"
)

func dump(plan config.Plan, tmpPath string, ts time.Time) (string, string, error) {

	archive := fmt.Sprintf("%v/%v-%v.gz", tmpPath, plan.Name, ts.Unix())
	log := fmt.Sprintf("%v/%v-%v.log", tmpPath, plan.Name, ts.Unix())

	dump := fmt.Sprintf("mongodump --archive=%v --gzip --host %v --port %v --db %v ",
		archive, plan.Target.Host, plan.Target.Port, plan.Target.Database)
	if plan.Target.Username != "" && plan.Target.Password != "" {
		dump += fmt.Sprintf("-u %v -p %v", plan.Target.Username, plan.Target.Password)
	}

	output, err := sh.Command("/bin/sh", "-c", dump).SetTimeout(time.Duration(plan.Scheduler.Timeout) * time.Minute).CombinedOutput()
	if err != nil {
		ex := ""
		if len(output) > 0 {
			ex = strings.Replace(string(output), "\n", " ", -1)
		}
		return "", "", errors.Wrapf(err, "mongodump log %v", ex)
	}
	logToFile(log, output)

	return archive, log, nil
}

func logToFile(file string, data []byte) error {
	if len(data) > 0 {
		err := ioutil.WriteFile(file, data, 0644)
		if err != nil {
			return errors.Wrapf(err, "writing log %v failed", file)
		}
	}

	return nil
}

func applyRetention(path string, retention int) error {
	gz := fmt.Sprintf("cd %v && rm -f $(ls -1t *.gz | tail -n +%v)", path, retention+1)
	err := sh.Command("/bin/sh", "-c", gz).Run()
	if err != nil {
		return errors.Wrapf(err, "removing old gz files from %v failed", path)
	}

	log := fmt.Sprintf("cd %v && rm -f $(ls -1t *.log | tail -n +%v)", path, retention+1)
	err = sh.Command("/bin/sh", "-c", log).Run()
	if err != nil {
		return errors.Wrapf(err, "removing old log files from %v failed", path)
	}

	return nil
}
