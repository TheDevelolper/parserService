#!/usr/bin/python3
import os
import subprocess
import logging
from logging.handlers import RotatingFileHandler
from flask import Flask, flash, request, redirect, url_for, send_from_directory, render_template, make_response
from datetime import datetime
from functools import wraps, update_wrapper
from werkzeug.utils import secure_filename

BASEDIR          = '/vagrant'
UPLOAD_FOLDER    = BASEDIR + '/uploads'
PROCESSED_FOLDER = BASEDIR + '/processed'
ALLOWED_EXTENSIONS = set(['txt','log'])

app = Flask(__name__, static_url_path='')
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['PROCESSED_FOLDER'] = PROCESSED_FOLDER
app.secret_key = 'some_secret' 

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1] in ALLOWED_EXTENSIONS

def process_file(parser, filein):
	cmd = ["perl", BASEDIR + "/parser/parser.pl", "-p", parser, "-l", filein, "-o", app.config['PROCESSED_FOLDER']]
	print ("cmd", cmd)
	p = subprocess.Popen(cmd, stdout = subprocess.PIPE,
							  stderr = subprocess.PIPE,
							  stdin = subprocess.PIPE)
	out,err = p.communicate()

def nocache(view):
    @wraps(view)
    def no_cache(*args, **kwargs):
        response = make_response(view(*args, **kwargs))
        response.headers['Last-Modified'] = datetime.now()
        response.headers['Cache-Control'] = 'no-store, no-cache, must-revalidate, post-check=0, pre-check=0, max-age=0'
        response.headers['Pragma'] = 'no-cache'
        response.headers['Expires'] = '-1'
        return response
        
    return update_wrapper(no_cache, view)
    
@app.route('/')
def root():
	return render_template("index.html")
	
@app.route('/upload_parser', methods=['GET', 'POST'])
def upload_parser():
    if request.method == 'POST':
        # check if the post request has the parser field
        parser = request.form['parser']
        print("parser: " + parser)
        
        # check if the post request has the file part
        if 'filein' not in request.files:
        # if 'filein' not in request.files['filein']:
            flash('No filein part')
            return redirect(request.url)
            
        file = request.files['filein']
        print("file: " + file.filename)
        # if user does not select file, browser also
        # submit a empty part without filename
        if file.filename == '':
            flash('No selected file')
            return redirect(request.url)
        print("is it an allowed_file?");
			
        if file and allowed_file(file.filename):
            filename = secure_filename(file.filename)
            filein  = os.path.join(app.config['UPLOAD_FOLDER'], filename)
            # Save the input file locally
            file.save(os.path.join(app.config['UPLOAD_FOLDER'], filename))

            
            pre, ext = os.path.splitext(filename)
            print ("pre: "+pre)
            json_file = pre+'.json'
            loghtmlfile = filename +'.html'
            
            print ("json_file: " + json_file)
            json_file_path = os.path.join(app.config['PROCESSED_FOLDER'], json_file)
            
            # Now process the file - output will be json file in processed folder
            process_file(parser, filein)

            # Render the processed file
            return render_template("plot_msc.html", parser=parser, msc_json=json_file, loghtml=loghtmlfile)
        else:
            print("Not a valid file type")
			
    return redirect('/')

@app.route('/uploads/<filename>')
@nocache
def uploaded_file(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'],
                               filename)


@app.route('/processed/<filename>')
@nocache
def processed_file(filename):
    return send_from_directory(app.config['PROCESSED_FOLDER'],
                               filename)

# Version to take csv file as a param				
@app.route('/plot_msc')
def plot_msc(parser=None, msc_json=None):
    return render_template('plot_msc.html', 
                           parser=parser, 
                           msc_json=msc_json)


@app.route('/test')
def plot_test(parser=None, msc_json=None):
    return render_template('plot_msc.html', 
                           parser="simple", 
                           msc_json="simple_msc.json",
                           loghtml="simple_msc.txt.html")
	
@app.route('/js/<path:path>')
def send_js(path):
	return send_from_directory('js', path)
	
@app.route('/lib/<path:path>')
def send_lib(path):
	return send_from_directory('lib', path)

@app.route('/css/<path:path>')
def send_css(path):
	return send_from_directory('css', path)
	
@app.route('/config')
def send_():
	return send_from_directory('parser', "parser_config.xml")

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0')