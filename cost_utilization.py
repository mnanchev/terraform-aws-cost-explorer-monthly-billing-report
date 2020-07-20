import calendar
import datetime
import os

from email.mime.application import MIMEApplication
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

import boto3
from botocore.exceptions import ClientError

if os.environ['CLIENT']:
    CLIENT = os.environ['CLIENT']
else:
    CLIENT = ''

SENDER = os.environ['SENDER']
SUBJECT = os.environ['SUBJECT']
RECIPIENT = os.environ['RECIPIENT']
bucket_name = os.environ['BUCKET_NAME']
client = boto3.client('ce')
s3 = boto3.resource("s3").Bucket(bucket_name)
s3_client = boto3.client('s3')

date_time = datetime.datetime.now() - datetime.timedelta(days=1)

key = str(date_time.year) + '/' + 'cost_explorer' + '{:%Y-%m-%d}'.format(
    date_time.replace(day=1)) + '.csv'
tmp = 'cost_utilization' + '{:%Y-%m-%d}'.format(
    date_time.replace(day=1)) + '.csv'
month = date_time.strftime("%B")
account_id = boto3.client('sts').get_caller_identity().get('Account')


def lambda_handler(event, context):
    response = client.get_cost_and_usage(TimePeriod={
        'Start':
        '{:%Y-%m-%d}'.format(date_time.replace(day=1)),
        'End':
        '{:%Y-%m-%d}'.format(
            date_time.replace(
                day=calendar.monthrange(date_time.year, date_time.month)[1]))
    },
                                         GroupBy=[{
                                             'Type': 'DIMENSION',
                                             'Key': 'SERVICE'
                                         }],
                                         Granularity='MONTHLY',
                                         Metrics=[
                                             'BlendedCost', 'UnblendedCost'
                                         ])
    builder = ','.join([
        'TimePeriod', 'Service', 'BlendedCost', 'UnblendedCost', 'Unit'
    ]) + '\n'
    multiLine = ""
    multiLine = multiLine + builder
    totalUnblendedCosts = 0
    totalBlendedCosts = 0
    for group in response['ResultsByTime']:
        for g in group['Groups']:
            amount = g['Metrics']['BlendedCost']['Amount']
            unit = g['Metrics']['BlendedCost']['Unit']
            amount_unblended = g['Metrics']['UnblendedCost']['Amount']
            multiLine = multiLine + str(month) + ',' + str(''.join(
                g['Keys'])) + ',' + str(round(float(amount), 4)) + ',' + str(
                    round(float(amount_unblended),
                          4)) + ',' + str(unit) + ',' + '\n'
            totalBlendedCosts += float(amount)
            totalUnblendedCosts += float(amount_unblended)

    multiLine = multiLine + 'TOTAL:,' + ',' + str(
        round(float(totalBlendedCosts), 4)) + ',' + str(
            round(float(totalUnblendedCosts), 4))
    s3_resource = boto3.resource('s3')
    s3_resource.Object(bucket_name, key).put(Body=multiLine)
    filepath = '/tmp/' + tmp

    s3_client.download_file(bucket_name, key, filepath)
    SUBJECT = f"AWS Cost Report for {month}"
    BODY_TEXT = f"Hello,\n\nPlease find attached the automatically generated " \
                f"cost report for AWS account(s) {account_id} for month " \
                f"{month}.\n\nThe report provides a breakdown of the costs " \
                f"per AWS service for the past month. The blended cost column shows the normal AWS cost for the service and the unblended one is the cost after the volume discount that you get from being part of the AWS Organisation.\n\nWe hope you will find this information useful.\n\nBest regards,\nSupport Team"

    CHARSET = "utf-8"

    ses = boto3.client('ses')
    msg = MIMEMultipart('mixed')
    msg['Subject'] = SUBJECT
    msg['From'] = SENDER
    msg['To'] = RECIPIENT

    msg_body = MIMEMultipart('alternative')

    textpart = MIMEText(BODY_TEXT.encode(CHARSET), 'plain', CHARSET)

    msg_body.attach(textpart)

    att = MIMEApplication(open(filepath, 'rb').read())

    att.add_header('Content-Disposition',
                   'attachment',
                   filename=os.path.basename(filepath))

    msg.attach(msg_body)

    msg.attach(att)
    # print(msg)
    try:
        response = ses.send_raw_email(
            Source=SENDER,
            Destinations=[
                RECIPIENT,
                'support@email.com',
            ],
            RawMessage={
                'Data': msg.as_string(),
            },
        )
    except ClientError as e:
        print(e.response['Error']['Message'])
    else:
        print("Email sent! Message ID:"),
        print(response['MessageId'])
